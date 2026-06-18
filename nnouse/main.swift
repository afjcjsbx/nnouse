import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()

withExtendedLifetime(controller) {
    app.run()
}
