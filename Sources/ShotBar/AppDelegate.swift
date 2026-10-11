import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = CaptureStore()
    private let clipboard = ClipboardStore()
    private let menu = NSMenu()
    private let limit = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初回は右寄り（Control Center のすぐ左あたり）に置く。macOS 27 は幅が足りないと左端から畳むので、
        // 新しい項目の既定位置（左端）だと「«」の裏に隠れる。以後の位置は ⌘ドラッグで動かした値が残る
        let positionKey = "NSStatusItem Preferred Position shotbar"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(260, forKey: positionKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "shotbar"
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ShotBar")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "ShotBar"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        store.onChange = { [weak self] in self?.prewarm() }
        clipboard.onChange = { [weak self] in self?.prewarm() }
        prewarm()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    // MARK: - メニュー

    private func rebuild() {
        menu.removeAllItems()
        let items = allItems()
        if let first = items.first {
            let head = NSMenuItem(title: title(for: first), action: #selector(openCapture(_:)), keyEquivalent: "")
            head.target = self
            head.representedObject = first
            Thumbnails.shared.image(for: first.url, size: .large) { head.image = $0 }
            menu.addItem(head)
            menu.addItem(action("開く", #selector(openCapture(_:)), first, key: "o"))
            menu.addItem(action("コピー", #selector(copyCapture(_:)), first, key: "c"))
            menu.addItem(action("パスをコピー", #selector(copyPath(_:)), first, key: "c", mods: [.command, .option]))
            menu.addItem(action("Finder で表示", #selector(reveal(_:)), first, key: "r"))

            if items.count > 1 {
                menu.addItem(.separator())
                for capture in items.dropFirst() {
                    let row = NSMenuItem(title: title(for: capture), action: nil, keyEquivalent: "")
                    Thumbnails.shared.image(for: capture.url, size: .small) { row.image = $0 }
                    let sub = NSMenu()
                    sub.autoenablesItems = false
                    sub.addItem(action("開く", #selector(openCapture(_:)), capture))
                    sub.addItem(action("コピー", #selector(copyCapture(_:)), capture))
                    sub.addItem(action("パスをコピー", #selector(copyPath(_:)), capture))
                    sub.addItem(action("Finder で表示", #selector(reveal(_:)), capture))
                    row.submenu = sub
                    menu.addItem(row)
                }
            }
        } else {
            let empty = NSMenuItem(title: "キャプチャが無い", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        menu.addItem(.separator())
        let folder = NSMenuItem(title: "保存先を開く", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        let retention = NSMenuItem(title: "クリップボードを残す日数", action: nil, keyEquivalent: "")
        let retentionMenu = NSMenu()
        retentionMenu.autoenablesItems = false
        for days in ClipboardStore.retentionChoices {
            let choice = NSMenuItem(title: "\(days) 日", action: #selector(setRetention(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = days
            choice.state = days == clipboard.retentionDays ? .on : .off
            retentionMenu.addItem(choice)
        }
        retention.submenu = retentionMenu
        menu.addItem(retention)
        let login = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "ShotBar を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func action(_ title: String, _ selector: Selector, _ capture: Capture,
                        key: String = "", mods: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = self
        item.representedObject = capture
        return item
    }

    /// 保存先のファイルとクリップボードから拾ったものを、新しい順に混ぜる。
    private func allItems() -> [Capture] {
        let merged = store.latest(limit: limit) + clipboard.items()
        return Array(merged.sorted { $0.date > $1.date }.prefix(limit))
    }

    private func title(for capture: Capture) -> String {
        if capture.source == .clipboard { return "クリップボード  \(Self.format(capture.date))" }
        let base = capture.url.deletingPathExtension().lastPathComponent
        let lower = base.lowercased()
        let kind: String
        if base.hasPrefix("スクリーンショット") || lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot") {
            kind = "スクリーンショット"
        } else if base.hasPrefix("画面収録") || lower.hasPrefix("screen recording") {
            kind = "画面収録"
        } else {
            return base
        }
        return "\(kind)  \(Self.format(capture.date))"
    }

    private static let timeOnly: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "HH:mm"; return f
    }()
    private static let dayAndTime: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M/d HH:mm"; return f
    }()

    private static func format(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? timeOnly.string(from: date) : dayAndTime.string(from: date)
    }

    private func prewarm() {
        for (i, capture) in allItems().enumerated() {
            Thumbnails.shared.image(for: capture.url, size: i == 0 ? .large : .small) { _ in }
        }
    }

    private func capture(from sender: Any?) -> Capture? {
        (sender as? NSMenuItem)?.representedObject as? Capture
    }

    // MARK: - 動作

    @objc private func openCapture(_ sender: Any?) {
        guard let c = capture(from: sender) else { return }
        NSWorkspace.shared.open(c.url)
    }

    @objc private func reveal(_ sender: Any?) {
        guard let c = capture(from: sender) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([c.url])
    }

    @objc private func copyPath(_ sender: Any?) {
        guard let c = capture(from: sender) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(c.url.path, forType: .string)
        clipboard.ownChangeCount = pb.changeCount
    }

    /// ファイル（file URL）と、画像なら画像データも同じ項目に載せる。
    /// Finder / Slack にはファイルとして、画像を受けるアプリには画像として貼れる。
    @objc private func copyCapture(_ sender: Any?) {
        guard let c = capture(from: sender) else { return }
        let item = NSPasteboardItem()
        item.setString(c.url.absoluteString, forType: .fileURL)
        if !c.isVideo, let image = NSImage(contentsOf: c.url) {
            if c.url.pathExtension.lowercased() == "png", let data = try? Data(contentsOf: c.url) {
                item.setData(data, forType: .png)
            } else if let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                item.setData(png, forType: .png)
            }
            if let tiff = image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item])
        clipboard.ownChangeCount = pb.changeCount
    }

    @objc private func openFolder() {
        guard let folder = store.folders.first else { return }
        NSWorkspace.shared.open(folder)
    }

    @objc private func setRetention(_ sender: Any?) {
        guard let days = (sender as? NSMenuItem)?.representedObject as? Int else { return }
        clipboard.retentionDays = days
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
