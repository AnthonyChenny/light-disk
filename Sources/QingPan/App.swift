import AppKit
import SwiftUI
import QingPanCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    static weak var shared: AppDelegate?
    let model = AppModel()
    private var status: NSStatusItem!
    private let popover = NSPopover()
    private var settings: NSWindow?
    private var preview: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = status.button {
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "轻盘")
            button.image?.isTemplate = true
            button.target = self; button.action = #selector(toggleMenu)
            button.toolTip = "轻盘 · 外接硬盘"
        }
        popover.behavior = .transient
        popover.delegate = self
        model.start()
        let menu = NSMenu()
        let appMenu = NSMenuItem(); appMenu.submenu = NSMenu()
        appMenu.submenu?.addItem(withTitle: "轻盘设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(withTitle: "退出轻盘", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(appMenu)
        let edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); edit.submenu = NSMenu(title: "编辑")
        edit.submenu?.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.submenu?.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(edit); NSApp.mainMenu = menu
        if CommandLine.arguments.contains("--preview") {
            let window = NSWindow(contentViewController: NSHostingController(rootView: MenuPanel(model: model, showSettings: { [weak self] in self?.showSettings() }, maximumHeight: (NSScreen.main?.visibleFrame.height ?? 820) - 32)))
            window.title = "轻盘"; window.styleMask = [.titled, .closable]; window.isReleasedWhenClosed = false
            window.center(); window.makeKeyAndOrderFront(nil); preview = window; NSApp.activate(ignoringOtherApps: true)
        } else if CommandLine.arguments.contains("--settings") || !FileManager.default.isExecutableFile(atPath: Product.engine) {
            showSettings()
        }
    }
    @objc func toggleMenu() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = status.button {
            model.refresh(); model.checkComponents()
            let screen = button.window?.screen ?? NSScreen.main
            popover.contentViewController = NSHostingController(rootView: MenuPanel(model: model, showSettings: { [weak self] in self?.showSettings() }, maximumHeight: (screen?.visibleFrame.height ?? 820) - 32))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    @objc func showSettings() {
        popover.performClose(nil)
        if settings == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsPanel(model: model)))
            window.title = "轻盘设置"; window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false; window.delegate = self; window.center(); settings = window
        }
        settings?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settings { settings = nil }
    }
    func popoverDidClose(_ notification: Notification) { popover.contentViewController = nil }
    func showUninstall() {
        let alert = NSAlert()
        alert.messageText = "卸载轻盘读写组件？"
        alert.informativeText = "请先在 Finder 中安全推出由轻盘挂载的 NTFS 磁盘。卸载将移除轻盘辅助服务与引擎，保留 macFUSE 和其他软件。系统会请求管理员授权。"
        alert.addButton(withTitle: "卸载组件"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let path = Bundle.main.path(forResource: "uninstall", ofType: "sh") else { return }
        let quoted = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let shell = "/bin/sh " + quoted
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if let error { self?.model.error = error[NSAppleScript.errorMessage] as? String ?? "卸载未完成" }
                else { self?.model.checkComponents() }
            }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
}

@main enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
