import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    init(appController: AppController) {
        super.init()
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
        button.target = self
        button.action = #selector(showMenu(_:))
    }

    private func setupMenu(appController: AppController) {
        menu.delegate = self

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
    }

    @objc private func openSettings() {
        menu.cancelTracking()
        DispatchQueue.main.async {
            SettingsWindowController.shared.showAndFocus()
        }
    }

    @objc private func showMenu(_ sender: Any?) {
        statusItem.popUpMenu(menu)
    }
}
