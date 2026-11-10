import ApplicationServices
import Foundation

// Cache one element in an explicitly supplied owned QA Window. No activation.
let args = CommandLine.arguments
guard args.count == 4, let pid = Int32(args[1]), AXIsProcessTrusted() else { exit(2) }
let output = URL(fileURLWithPath: args[2])
let title = args[3]
let application = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(application, 0.2)
func attribute(_ element: AXUIElement, _ name: String) -> Any? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func write(_ name: String, _ value: [String: Any]) throws {
    let bytes = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try bytes.write(to: output.appendingPathComponent(name), options: .atomic)
}
func snapshot() -> ([[String: Any]], [AXUIElement]) {
    var rows: [[String: Any]] = []
    var matches: [AXUIElement] = []
    func walk(_ element: AXUIElement, _ path: [Int]) {
        if rows.count >= 5000 || path.count > 40 { return }
        var row: [String: Any] = ["path": path]
        for name in ["AXRole", "AXTitle", "AXEnabled"] {
            if let value = attribute(element, name) {
                if let string = value as? String { row[name] = string }
                else if let number = value as? NSNumber { row[name] = number }
            }
        }
        if row["AXRole"] as? String == "AXButton", row["AXTitle"] as? String == title { matches.append(element) }
        rows.append(row)
        if let children = attribute(element, "AXChildren") as? [AXUIElement] {
            for (i, child) in children.enumerated() { walk(child, path + [i]) }
        }
    }
    if let windows = attribute(application, "AXWindows") as? [AXUIElement] {
        for (i, window) in windows.enumerated() { walk(window, [i]) }
    }
    return (rows, matches)
}
var initial: ([[String: Any]], [AXUIElement]) = ([], [])
for _ in 0..<20 {
    initial = snapshot()
    if initial.1.count == 1 { break }
    Thread.sleep(forTimeInterval: 0.1)
}
guard initial.1.count == 1 else {
    try write("visible-ax.json", ["pid":pid, "rows":initial.0, "cache_matches":initial.1.count])
    exit(3)
}
let cached = initial.1[0]
try write("visible-ax.json", ["pid":pid, "rows":initial.0, "cache_matches":1, "cached_title":title])
try write("visible-done.json", [:])
let deadline = Date().addingTimeInterval(25)
while !FileManager.default.fileExists(atPath: output.appendingPathComponent("hidden-ready.json").path) {
    if Date() > deadline { exit(4) }
    Thread.sleep(forTimeInterval: 0.05)
}
let hidden = snapshot()
// The element came from the visible snapshot; do not find a replacement.
let result = AXUIElementPerformAction(cached, kAXPressAction as CFString)
try write("hidden-ax.json", ["pid":pid, "rows":hidden.0, "fresh_matches":hidden.1.count,
                            "cached_title":title, "cached_press_error":result.rawValue])
try write("hidden-done.json", [:])
print("CACHED AX fresh_matches=\(hidden.1.count) press_error=\(result.rawValue)")
