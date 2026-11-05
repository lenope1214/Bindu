import AppKit
import CoreGraphics
import Foundation
let baseline = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
let task = Process()
task.executableURL = URL(fileURLWithPath: "/bin/zsh")
task.arguments = ["-c", CommandLine.arguments[1]]
let log = FileHandle(forWritingAtPath: CommandLine.arguments[2])!
task.standardOutput = log
task.standardError = log
try task.run()
var samples = 0
var focusChanges = 0
var activated: [Int32] = []
while task.isRunning {
    if NSWorkspace.shared.frontmostApplication?.processIdentifier != baseline { focusChanges += 1 }
    if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != baseline,
       app.executableURL?.path.contains("Godot.app") == true {
        activated.append(app.processIdentifier)
    }
    samples += 1
    Thread.sleep(forTimeInterval: 0.02)
}
task.waitUntilExit()
print("OS_OBSERVATION samples=\(samples) new_godot_focus=\(Set(activated).count) frontmost_changes=\(focusChanges) exit=\(task.terminationStatus)")
exit(task.terminationStatus == 0 && activated.isEmpty ? 0 : 1)
