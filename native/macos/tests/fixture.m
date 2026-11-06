#import <Cocoa/Cocoa.h>
#include <unistd.h>
#include <fcntl.h>
@interface FixtureDelegate : NSObject <NSApplicationDelegate>
@end
@implementation FixtureDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSDictionary *p = NSBundle.mainBundle.infoDictionary;
    NSString *line = [NSString stringWithFormat:@"%@ %d\n", p[@"CFBundleShortVersionString"], getpid()];
    int fd = open([p[@"BinduTestOutput"] fileSystemRepresentation], O_CREAT | O_WRONLY | O_APPEND, 0600);
    if (fd >= 0) { write(fd, line.UTF8String, strlen(line.UTF8String)); close(fd); }
    if ([p[@"BinduTestCrash"] boolValue]) exit(1);
    NSArray *args = NSProcessInfo.processInfo.arguments;
    NSUInteger state = [args indexOfObject:@"--bindu-update-state"], token = [args indexOfObject:@"--bindu-update-token"];
    if (![p[@"BinduTestNoAck"] boolValue] && state != NSNotFound && token != NSNotFound && state + 1 < args.count && token + 1 < args.count)
        [args[token + 1] writeToFile:[args[state + 1] stringByAppendingPathComponent:@"ready"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, ([p[@"BinduTestNoAck"] boolValue] ? 60 : 10) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [NSApp terminate:nil]; });
}
@end
int main(int argc, const char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        FixtureDelegate *delegate = [FixtureDelegate new];
        NSApp.delegate = delegate;
        [NSApp run];
        (void)delegate;
    }
    return 0;
}
