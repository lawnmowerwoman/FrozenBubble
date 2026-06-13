import AppKit
import SpriteKit

private func installApplicationMenu() {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()

    appMenu.addItem(
        withTitle: "Quit Frozen Bubble Swift",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )

    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)
    NSApp.mainMenu = mainMenu
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sceneSize = CGSize(width: 640, height: 480)
        let skView = SKView(frame: NSRect(origin: .zero, size: sceneSize))
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false

        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: sceneSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Frozen Bubble Swift"
        window.contentView = skView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
installApplicationMenu()
app.run()
