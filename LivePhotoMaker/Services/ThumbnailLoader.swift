import ImageIO
import UIKit

/// 从 JPG 生成列表缩略图，并做简单内存缓存。
enum ThumbnailLoader {
    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    static func thumbnail(for url: URL, maxPixelSize: CGFloat = 160) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // 说明：这里用 DispatchQueue + continuation 而不是 Task.detached，
        // 因为 Task 的 Success 类型要求 Sendable，而 UIImage 不是 Sendable，
        // 直接返回 UIImage 会在并发检查较严格时报警告（未来 Swift 6 会报错）。
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let image = decodeThumbnail(url: url, maxPixelSize: maxPixelSize)
                if let image {
                    cache.setObject(image, forKey: url as NSURL)
                }
                continuation.resume(returning: image)
            }
        }
    }

    private static func decodeThumbnail(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
