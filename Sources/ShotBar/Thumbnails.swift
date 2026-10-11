import AppKit
import QuickLookThumbnailing

enum ThumbSize {
    case large, small

    var points: CGSize {
        switch self {
        case .large: return CGSize(width: 180, height: 112)
        case .small: return CGSize(width: 64, height: 40)
        }
    }
}

/// QuickLook でサムネイルを作り、パスと大きさで覚える。
final class Thumbnails {
    static let shared = Thumbnails()
    private var cache: [String: NSImage] = [:]

    func image(for url: URL, size: ThumbSize, completion: @escaping (NSImage) -> Void) {
        let key = "\(size)|\(url.path)"
        if let img = cache[key] { completion(img); return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size.points, scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            guard let rep else { return }
            let img = rep.nsImage
            DispatchQueue.main.async {
                if self.cache.count > 200 { self.cache.removeAll() }
                self.cache[key] = img
                completion(img)
            }
        }
    }
}
