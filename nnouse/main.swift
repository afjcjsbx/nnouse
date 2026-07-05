import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()
SelfTestRunner.maybeRun()

withExtendedLifetime(controller) {
    app.run()
}
