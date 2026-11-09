import ApplicationServices
import Foundation

// Reads only the explicitly supplied owned QA PID. No activation or system input.
let args = CommandLine.arguments
guard args.count >= 3, let pid = Int32(args[1]), AXIsProcessTrusted() else { exit(2) }
let application = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(application, 0.2)
var lastError: Int32 = 0
func attribute(_ element: AXUIElement, _ name: String) -> Any? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    lastError = error.rawValue
    return error == .success ? value : nil
}
var rows: [[String: Any]] = []
var targets: [AXUIElement] = []
let press = args.count > 3 ? args[3] : nil
func walk(_ element: AXUIElement, _ path: [Int]) {
    if path.count > 40 || rows.count >= 5000 { return }
    var row: [String: Any] = ["path": path]
    var errors: [String: Int32] = [:]
    for name in ["AXRole", "AXSubrole", "AXTitle", "AXDescription", "AXValue", "AXHelp", "AXEnabled", "AXFocused", "AXIdentifier"] {
        if let value = attribute(element, name) {
            if let string = value as? String { row[name] = string }
            else if let number = value as? NSNumber { row[name] = number }
        } else { errors[name] = lastError }
    }
    var actionNames: CFArray?
    if AXUIElementCopyActionNames(element, &actionNames) == .success { row["actions"] = actionNames as? [String] ?? [] }
    if let press = press, row["AXRole"] as? String == "AXButton", [row["AXTitle"] as? String, row["AXDescription"] as? String].contains(press) { targets.append(element) }
    rows.append(row)
    rows[rows.count - 1]["attribute_errors"] = errors
    if let children = attribute(element, "AXChildren") as? [AXUIElement] {
        for (i, child) in children.enumerated() { walk(child, path + [i]) }
    }
}
// Limit traversal to this app's windows; do not read the shared macOS menu bar.
if let windows = attribute(application, "AXWindows") as? [AXUIElement] {
    for (i, window) in windows.enumerated() { walk(window, [i]) }
}
var result: [String: Any] = ["pid": pid, "trusted": true, "rows": rows, "limit_reached": rows.count >= 5000]
if let press = press {
    result["press_title"] = press
    result["press_matches"] = targets.count
    if targets.count == 1 { result["press_error"] = AXUIElementPerformAction(targets[0], kAXPressAction as CFString).rawValue }
}
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
print("AX rows=\(rows.count) press_matches=\(targets.count)")
