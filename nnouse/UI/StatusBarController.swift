import AppKit

final class StatusBarController {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isEnabled = true

    init(appController: AppController) {
        setupButton()
        setupMenu(appController: appController)
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        // Use SF Symbol as icon; fall back to text if unavailable
        if let img = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "nnouse") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "⊹"
        }
        button.toolTip = "nnouse"
    }

    private func setupMenu(appController: AppController) {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Activate Grid", action: #selector(AppController.toggleOverlay), keyEquivalent: "")
        toggleItem.target = appController
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showAndFocus()
    }
}
