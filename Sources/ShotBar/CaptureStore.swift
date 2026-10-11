import Foundation

enum CaptureSource {
    case file, clipboard
}

struct Capture {
    let url: URL
    let date: Date
    let isVideo: Bool
    let source: CaptureSource
}

/// 純正のスクリーンショット・画面収録の保存先を読み、直近のファイルを返す。
final class CaptureStore {
    static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "tif", "webp"]
    static let videoExts: Set<String> = ["mov", "mp4", "m4v"]

    let folders: [URL]
    var onChange: (() -> Void)?

    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: DispatchWorkItem?

    init() {
        folders = CaptureStore.resolveFolders()
        startWatching()
    }

    /// `defaults read com.apple.screencapture` の location 系を読む。無ければ ~/Desktop。
    static func resolveFolders() -> [URL] {
        let prefs = UserDefaults(suiteName: "com.apple.screencapture")
        var paths: [String] = []
        for key in ["location-screenshot", "location-screenrecording", "location"] {
            if let p = prefs?.string(forKey: key), !p.isEmpty { paths.append(p) }
        }
        let desktop = NSHomeDirectory() + "/Desktop"
        if paths.isEmpty { paths = [desktop] }
        var seen = Set<String>()
        var out: [URL] = []
        for p in paths {
            let url = URL(fileURLWithPath: (p as NSString).expandingTildeInPath).standardizedFileURL
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if seen.insert(url.path).inserted { out.append(url) }
        }
        return out.isEmpty ? [URL(fileURLWithPath: desktop)] : out
    }

    func latest(limit: Int) -> [Capture] {
        let keys: Set<URLResourceKey> = [.creationDateKey, .addedToDirectoryDateKey, .contentModificationDateKey, .isRegularFileKey]
        var items: [Capture] = []
        for folder in folders {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { continue }
            for url in urls {
                let ext = url.pathExtension.lowercased()
                let isVideo = CaptureStore.videoExts.contains(ext)
                guard isVideo || CaptureStore.imageExts.contains(ext) else { continue }
                guard let rv = try? url.resourceValues(forKeys: keys), rv.isRegularFile == true else { continue }
                let date = rv.creationDate ?? rv.addedToDirectoryDate ?? rv.contentModificationDate ?? .distantPast
                items.append(Capture(url: url, date: date, isVideo: isVideo, source: .file))
            }
        }
        items.sort { $0.date > $1.date }
        return Array(items.prefix(limit))
    }

    private func startWatching() {
        for folder in folders {
            let fd = open(folder.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .delete, .attrib], queue: .main)
            src.setEventHandler { [weak self] in self?.scheduleChange() }
            src.setCancelHandler { close(fd) }
            src.resume()
            sources.append(src)
        }
    }

    private func scheduleChange() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
