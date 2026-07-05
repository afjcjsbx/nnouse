import AppKit
import Foundation

enum SelfTestRunner {
    static func maybeRun() {
        guard ProcessInfo.processInfo.environment["NNOUSE_SELFTEST"] == "1" else { return }

        DispatchQueue.main.async {
            SettingsWindowController.shared.showAndFocus()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let results = SettingsWindowController.shared.runShortcutSelfTest()
                let failed = results.contains { $0.hasPrefix("FAIL:") }
                let outputLines = results + [failed ? "SELFTEST RESULT: FAIL" : "SELFTEST RESULT: PASS"]
                outputLines.forEach { print($0) }
                writeOutputIfNeeded(lines: outputLines)
                NSApp.terminate(nil)
            }
        }
    }

    private static func writeOutputIfNeeded(lines: [String]) {
        guard let path = ProcessInfo.processInfo.environment["NNOUSE_SELFTEST_OUTPUT"] else { return }
        let contents = lines.joined(separator: "\n") + "\n"
        try? contents.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
