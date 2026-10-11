import AppKit
import CryptoKit

/// クリップボードに撮ったスクリーンショット（ファイルも URL も文字も無い、画像だけの項目）を拾い、
/// Application Support に PNG で残して一定期間で消す。
final class ClipboardStore {
    static let retentionKey = "clipboardRetentionDays"
    static let retentionChoices = [1, 3, 7, 14]

    let folder: URL
    var onChange: (() -> Void)?
    /// 自分が書いた changeCount。拾わない
    var ownChangeCount = -1

    private var lastChangeCount: Int
    private var lastDigest: String?
    private var timers: [Timer] = []
    private let nameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f
    }()

    var retentionDays: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.retentionKey)
            return v > 0 ? v : 7
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.retentionKey)
            prune()
        }
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        folder = base.appendingPathComponent("ShotBar/clipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        lastChangeCount = NSPasteboard.general.changeCount
        prune()
        timers.append(Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() })
        timers.append(Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.prune() })
    }

    func items() -> [Capture] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "png" }.map { url in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return Capture(url: url, date: date, isVideo: false, source: .clipboard)
        }
    }

    func prune() {
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        var removed = false
        for c in items() where c.date < cutoff {
            try? FileManager.default.removeItem(at: c.url)
            removed = true
        }
        if removed { onChange?() }
    }

    private func poll() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard count != ownChangeCount, let types = pb.types else { return }
        guard types.contains(.png) || types.contains(.tiff) else { return }
        let others: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .html, .rtf, .string, .pdf]
        guard !types.contains(where: { others.contains($0) }) else { return }
        if #available(macOS 15.4, *), pb.accessBehavior == .alwaysDeny { return }

        let png: Data?
        if let data = pb.data(forType: .png) {
            png = data
        } else if let tiff = pb.data(forType: .tiff) {
            png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        } else {
            png = nil
        }
        guard let png else { return }
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        guard digest != lastDigest else { return }
        lastDigest = digest

        let stamp = nameFormatter.string(from: Date())
        var url = folder.appendingPathComponent("クリップボード \(stamp).png")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("クリップボード \(stamp) \(n).png")
            n += 1
        }
        do {
            try png.write(to: url)
            onChange?()
        } catch {
            NSLog("ShotBar: clipboard save failed: \(error.localizedDescription)")
        }
    }
}
