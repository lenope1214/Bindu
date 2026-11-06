// Direct-distribution updater. No elevation, shell evaluation, or in-place executable writes.
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <archive.h>
#include <archive_entry.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <signal.h>
#include <unistd.h>
#include <spawn.h>
#include <sys/wait.h>
#include <crt_externs.h>

static NSFileManager *fm;
static NSString *const bundleID = @"kr.chat.anon.bindu";
static const int startupTimeout = 45;

static void require(BOOL ok, NSString *message) {
    if (!ok) @throw [NSException exceptionWithName:@"UpdateError" reason:message userInfo:nil];
}
static NSString *canonical(NSString *path) {
    char *resolved = realpath(path.fileSystemRepresentation, NULL);
    if (!resolved) return @"";
    NSString *value = [@(resolved) precomposedStringWithCanonicalMapping];
    free(resolved);
    return value;
}
static void writeJSON(NSString *path, NSDictionary *data) {
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    require(bytes && [bytes writeToFile:path options:NSDataWritingAtomic error:nil], @"업데이트 상태를 저장하지 못했어요");
}
static NSDictionary *readJSON(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    require([value isKindOfClass:NSDictionary.class], @"업데이트 상태가 올바르지 않아요");
    return value;
}
static void swap(NSString *from, NSString *to) {
    require(renamex_np(from.fileSystemRepresentation, to.fileSystemRepresentation, RENAME_SWAP) == 0, @"앱을 교체하지 못했어요");
}
static int tool(NSString *path, NSArray *args, NSString **output) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:path]; task.arguments = args;
    NSPipe *pipe = [NSPipe pipe]; task.standardOutput = pipe; task.standardError = pipe;
    if (![task launchAndReturnError:nil]) return -1;
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    if (output) *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    return task.terminationStatus;
}
static NSString *hash(NSString *path) {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    [stream open]; CC_SHA256_CTX ctx; CC_SHA256_Init(&ctx);
    uint8_t buf[65536]; NSInteger count;
    while ((count = [stream read:buf maxLength:sizeof(buf)]) > 0) CC_SHA256_Update(&ctx, buf, (CC_LONG)count);
    [stream close]; require(count == 0, @"다운로드 파일을 읽지 못했어요");
    uint8_t digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256_Final(digest, &ctx);
    NSMutableString *text = [NSMutableString new];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [text appendFormat:@"%02x", digest[i]];
    return text;
}
static NSDictionary *info(NSString *app) {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Contents/Info.plist"]];
    require([p[@"CFBundleIdentifier"] isEqual:bundleID], @"Bindu 앱이 아닌 파일이에요");
    NSString *exe = p[@"CFBundleExecutable"];
    require([exe isKindOfClass:NSString.class] && exe.length && [exe isEqual:exe.lastPathComponent], @"앱 실행 파일 정보가 올바르지 않아요");
    NSString *path = [app stringByAppendingPathComponent:[@"Contents/MacOS" stringByAppendingPathComponent:exe]];
    require([fm isExecutableFileAtPath:path], @"앱 실행 권한이 없어요");
    return p;
}
static NSString *team(NSString *app) {
    NSString *out;
    require(tool(@"/usr/bin/codesign", @[@"--verify", @"--deep", @"--strict", app], nil) == 0, @"앱 코드 서명이 올바르지 않아요");
    require(tool(@"/usr/bin/codesign", @[@"-dv", @"--verbose=4", app], &out) == 0, @"앱 서명을 읽지 못했어요");
    for (NSString *line in [out componentsSeparatedByString:@"\n"])
        if ([line hasPrefix:@"TeamIdentifier="]) return [line substringFromIndex:15];
    return @"not set";
}
static void validateNew(NSString *app, NSString *old, NSString *version) {
    NSDictionary *p = info(app); info(old);
    require([p[@"CFBundleShortVersionString"] isEqual:version], @"다운로드한 앱 버전이 맞지 않아요");
    NSString *oldTeam = team(old), *newTeam = team(app);
    if (![oldTeam isEqual:@"not set"]) require([oldTeam isEqual:newTeam], @"앱 서명 개발자가 달라요");
}
static BOOL safeRelative(NSString *path) {
    return path.length && !path.isAbsolutePath && ![path.pathComponents containsObject:@".."];
}
static void extract(NSString *zip, NSString *destination) {
    require([fm createDirectoryAtPath:destination withIntermediateDirectories:NO attributes:nil error:nil], @"압축 해제 폴더를 만들지 못했어요");
    require(chdir(destination.fileSystemRepresentation) == 0, @"압축 해제 폴더를 열지 못했어요");
    struct archive *reader = archive_read_new(), *writer = archive_write_disk_new();
    archive_read_support_format_zip(reader); archive_read_support_filter_all(reader);
    archive_write_disk_set_options(writer, ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_TIME |
        ARCHIVE_EXTRACT_SECURE_SYMLINKS | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS);
    @try {
        require(archive_read_open_filename(reader, zip.fileSystemRepresentation, 65536) == ARCHIVE_OK, @"ZIP 파일을 열지 못했어요");
        struct archive_entry *entry; int result; int entries = 0; int64_t total = 0;
        while ((result = archive_read_next_header(reader, &entry)) == ARCHIVE_OK) {
            NSString *path = @(archive_entry_pathname(entry));
            require(safeRelative(path) && [path.pathComponents.firstObject isEqual:@"Bindu.app"], @"ZIP 내부 경로가 올바르지 않아요");
            mode_t type = archive_entry_filetype(entry);
            require(type == AE_IFREG || type == AE_IFDIR || type == AE_IFLNK, @"지원하지 않는 ZIP 항목이에요");
            require(!archive_entry_hardlink(entry), @"ZIP의 하드 링크는 허용하지 않아요");
            if (type == AE_IFLNK) {
                const char *raw = archive_entry_symlink(entry);
                require(raw != NULL, @"심볼릭 링크가 올바르지 않아요");
                NSString *target = @(raw);
                NSString *resolved = [[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:target] stringByStandardizingPath];
                require(!target.isAbsolutePath && [resolved hasPrefix:@"Bindu.app/"], @"앱 밖으로 나가는 심볼릭 링크예요");
            }
            int64_t fileSize = archive_entry_size(entry);
            require(fileSize >= 0 && fileSize <= 2LL * 1024 * 1024 * 1024 - total && ++entries <= 50000, @"압축 해제 크기가 너무 커요");
            total += fileSize;
            archive_entry_set_perm(entry, archive_entry_perm(entry) & 0777);
            require(archive_write_header(writer, entry) == ARCHIVE_OK, @"ZIP 항목을 만들지 못했어요");
            const void *data; size_t size; la_int64_t offset;
            int block;
            while ((block = archive_read_data_block(reader, &data, &size, &offset)) == ARCHIVE_OK) {
                require(offset >= 0 && offset <= fileSize && size <= (uint64_t)(fileSize - offset), @"ZIP 항목 크기가 올바르지 않아요");
                require(archive_write_data_block(writer, data, size, offset) == ARCHIVE_OK, @"ZIP 항목을 쓰지 못했어요");
            }
            require(block == ARCHIVE_EOF && archive_write_finish_entry(writer) == ARCHIVE_OK, @"ZIP 데이터가 손상됐어요");
        }
        require(result == ARCHIVE_EOF && entries > 0, @"ZIP 데이터가 손상됐어요");
    } @finally { archive_write_free(writer); archive_read_free(reader); }
    NSString *app = [destination stringByAppendingPathComponent:@"Bindu.app"];
    for (NSString *relative in [fm enumeratorAtPath:app]) {
        NSString *path = [app stringByAppendingPathComponent:relative];
        require([canonical(path) hasPrefix:[canonical(app) stringByAppendingString:@"/"]], @"앱 밖으로 나가는 경로가 있어요");
    }
}
static BOOL privateStage(NSString *stage) {
    struct stat st;
    return stage.isAbsolutePath && [stage.lastPathComponent hasPrefix:@".bindu-update-"] &&
        ![stage.pathComponents containsObject:@".."] && lstat(stage.fileSystemRepresentation, &st) == 0 &&
        S_ISDIR(st.st_mode) && st.st_uid == getuid();
}
static void validatePaths(NSString *app, NSString *stage) {
    struct stat st;
    require(app.isAbsolutePath && [app.pathExtension isEqual:@"app"] && ![app.pathComponents containsObject:@".."] &&
        lstat(app.fileSystemRepresentation, &st) == 0 && S_ISDIR(st.st_mode), @"앱 설치 경로가 올바르지 않아요");
    require(privateStage(stage) && [canonical(stage.stringByDeletingLastPathComponent) isEqual:canonical(app.stringByDeletingLastPathComponent)], @"업데이트 임시 경로가 올바르지 않아요");
    require([fm isWritableFileAtPath:app.stringByDeletingLastPathComponent], @"앱이 있는 폴더에 쓸 수 없어요");
}
static pid_t launch(NSString *app, NSArray<NSString *> *arguments) {
    // Spawn the validated bundle executable directly: no LaunchServices cache or blocking launch handshake.
    NSDictionary *p = info(app);
    NSString *executable = [app stringByAppendingPathComponent:[@"Contents/MacOS" stringByAppendingPathComponent:p[@"CFBundleExecutable"]]];
    char **args = calloc(arguments.count + 2, sizeof(char *));
    require(args != NULL, @"새 버전 실행 인자를 준비하지 못했어요");
    args[0] = (char *)executable.fileSystemRepresentation;
    for (NSUInteger i = 0; i < arguments.count; i++) args[i + 1] = (char *)arguments[i].UTF8String;
    posix_spawnattr_t attributes;
    posix_spawnattr_init(&attributes);
    posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
    pid_t pid = -1;
    int error = posix_spawn(&pid, executable.fileSystemRepresentation, NULL, &attributes, args, *_NSGetEnviron());
    posix_spawnattr_destroy(&attributes);
    free(args);
    require(error == 0, @"새 버전을 켜지 못했어요");
    return pid;
}
static void prepare(NSString *app, NSString *stage, NSString *sha, NSString *version, NSString *receipt) {
    validatePaths(app, stage);
    require(chmod(stage.fileSystemRepresentation, 0700) == 0, @"임시 폴더 권한을 설정하지 못했어요");
    NSString *zip = [stage stringByAppendingPathComponent:@"update.zip"];
    require([hash(zip) isEqual:sha], @"받은 파일이 맞지 않아요");
    NSString *unpacked = [stage stringByAppendingPathComponent:@"unpacked"];
    extract(zip, unpacked);
    validateNew([unpacked stringByAppendingPathComponent:@"Bindu.app"], app, version);
    NSDictionary *attributes = [fm attributesOfItemAtPath:app error:nil];
    writeJSON([stage stringByAppendingPathComponent:@"manifest.json"], @{
        @"app":app, @"version":version, @"inode":attributes[NSFileSystemFileNumber],
        @"token":NSUUID.UUID.UUIDString, @"receipt":receipt});
    writeJSON([stage stringByAppendingPathComponent:@"prepared.json"], @{@"ok":@YES});
}
static BOOL alive(pid_t pid) {
    return pid > 1 && waitpid(pid, NULL, WNOHANG) == 0;
}
static void install(NSString *app, NSString *stage, pid_t parent) {
    validatePaths(app, stage);
    require(parent > 1 && parent != getpid(), @"기존 앱 프로세스 정보가 올바르지 않아요");
    NSDictionary *m = readJSON([stage stringByAppendingPathComponent:@"manifest.json"]);
    require([m[@"app"] isEqual:app], @"업데이트 대상이 달라요");
    NSString *lock = [app.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".bindu-update.lock"];
    int lockFD = open(lock.fileSystemRepresentation, O_CREAT | O_RDWR | O_NOFOLLOW, 0600);
    require(lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0, @"다른 업데이트가 진행 중이에요");
    NSString *next = [stage stringByAppendingPathComponent:@"unpacked/Bindu.app"];
    pid_t newProcess = -1;
    BOOL swapped = NO, parentExited = NO;
    @try {
        writeJSON([stage stringByAppendingPathComponent:@"installing.json"], @{@"ok":@YES});
        for (int i = 0; i < 300 && kill(parent, 0) == 0; i++) usleep(100000);
        require(kill(parent, 0) != 0 && errno == ESRCH, @"기존 앱이 종료되지 않았어요");
        parentExited = YES;
        NSDictionary *attributes = [fm attributesOfItemAtPath:app error:nil];
        require([attributes[NSFileSystemFileNumber] isEqual:m[@"inode"]], @"설치된 앱이 준비 중에 바뀌었어요");
        validateNew(next, app, m[@"version"]);
        swap(app, next); swapped = YES;
        newProcess = launch(app, @[@"--", @"--bindu-update-state", stage, @"--bindu-update-token", m[@"token"]]);
        BOOL ready = NO;
        for (int i = 0; i < startupTimeout * 10; i++) {
            NSString *ack = [NSString stringWithContentsOfFile:[stage stringByAppendingPathComponent:@"ready"] encoding:NSUTF8StringEncoding error:nil];
            if ([ack isEqual:m[@"token"]] && alive(newProcess)) { ready = YES; break; }
            if (!alive(newProcess)) break;
            usleep(100000);
        }
        require(ready, @"새 버전의 시작을 확인하지 못했어요");
        [fm removeItemAtPath:stage error:nil];
    } @catch (NSException *error) {
        if (alive(newProcess)) {
            kill(newProcess, SIGTERM);
            for (int i = 0; i < 30 && alive(newProcess); i++) usleep(100000);
            if (alive(newProcess)) kill(newProcess, SIGKILL);
            for (int i = 0; i < 30 && alive(newProcess); i++) usleep(100000);
            require(!alive(newProcess), @"새 앱을 종료하지 못했어요. 이전 앱은 임시 폴더에 보존했어요");
        }
        if (swapped) swap(app, next);
        writeJSON(m[@"receipt"], @{@"error":error.reason ?: @"업데이트 실패", @"stage":stage});
        if (parentExited) launch(app, @[]);
        @throw error;
    } @finally { flock(lockFD, LOCK_UN); close(lockFD); }
}
int main(int argc, const char **argv) {
    @autoreleasepool {
        fm = NSFileManager.defaultManager;
        NSString *stage = argc > 3 ? @(argv[3]) : @"";
        @try {
            require(argc >= 4, @"업데이트 인자가 부족해요");
            NSString *mode = @(argv[1]), *app = @(argv[2]);
            if ([mode isEqual:@"prepare"] && argc == 7) prepare(app, stage, @(argv[4]), @(argv[5]), @(argv[6]));
            else if ([mode isEqual:@"install"] && argc == 5) install(app, stage, (pid_t)strtol(argv[4], NULL, 10));
            else require(NO, @"업데이트 인자가 올바르지 않아요");
            return 0;
        } @catch (NSException *error) {
            // Only write status inside an existing, private updater stage.
            if (privateStage(stage))
                @try { writeJSON([stage stringByAppendingPathComponent:@"prepared.json"], @{@"ok":@NO, @"error":error.reason ?: @"업데이트 실패"}); } @catch (...) {}
            fprintf(stderr, "%s\n", error.reason.UTF8String);
            return 1;
        }
    }
}
