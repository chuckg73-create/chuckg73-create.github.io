import Foundation
import UIKit

/// Durable storage for a cook's OWN photos of a recipe (a snap of the peanut
/// butter fudge they actually made). Unlike `RecipeImageCache` — which holds
/// AI-generated photos in the purgeable Caches directory — these live in
/// Application Support so they survive relaunches and storage pressure, and take
/// priority over both web and AI images everywhere the recipe appears.
///
/// Keyed by the recipe's stable `id`. The absolute path is resolved fresh from
/// the current container each call (never persisted), so photos keep working
/// across app updates that move the container.
final class RecipeUserPhotoStore {
    static let shared = RecipeUserPhotoStore()

    private let memory = NSCache<NSString, UIImage>()
    private let io = DispatchQueue(label: "com.kindred.RecipeUserPhotoStore", qos: .utility)
    private let fm = FileManager.default

    private init() { memory.countLimit = 80 }

    /// Directory resolved live each call — Application Support container paths can
    /// change between app updates, so we never store an absolute path.
    private var directory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("RecipeUserPhotos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func fileURL(_ id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
    }

    func hasPhoto(for id: UUID) -> Bool {
        if memory.object(forKey: id.uuidString as NSString) != nil { return true }
        return io.sync { fm.fileExists(atPath: fileURL(id).path) }
    }

    func image(for id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let hit = memory.object(forKey: key) { return hit }
        return io.sync {
            guard let data = try? Data(contentsOf: fileURL(id)),
                  let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: key)
            return image
        }
    }

    /// Persists a cook's photo. Downscales/compresses to keep the file modest.
    @discardableResult
    func save(_ image: UIImage, for id: UUID) -> Bool {
        let prepared = image.downscaled(maxDimension: 1400)
        guard let data = prepared.jpegData(compressionQuality: 0.82) else { return false }
        memory.setObject(prepared, forKey: id.uuidString as NSString)
        io.async { [weak self] in
            guard let self else { return }
            try? data.write(to: self.fileURL(id), options: .atomic)
        }
        return true
    }

    func remove(for id: UUID) {
        memory.removeObject(forKey: id.uuidString as NSString)
        io.async { [weak self] in
            guard let self else { return }
            try? self.fm.removeItem(at: self.fileURL(id))
        }
    }
}

private extension UIImage {
    /// Aspect-fit downscale so the longest side is at most `maxDimension`.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
