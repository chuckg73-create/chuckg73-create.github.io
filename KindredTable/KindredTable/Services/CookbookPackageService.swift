import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A whole exported KindredTable cookbook — see `CookbookPackage`.
    /// Declared in BaseInfo.plist (`UTExportedTypeDeclarations` +
    /// `CFBundleDocumentTypes`) so Files/Mail/Messages recognize the app as
    /// the owner of `.kindredcookbook` attachments.
    static var kindredCookbook: UTType {
        UTType(exportedAs: "com.kindred.kindredtable.cookbook")
    }
}

enum CookbookPackageError: Error {
    case cannotAccessFile
    case notAKindredCookbook
}

/// Builds and reads the single-file cookbook handoff: every recipe plus every
/// attached photo, packaged so a whole collection can be handed to family in
/// one AirDrop/Messages/Mail share and imported back as real recipes.
enum CookbookPackageService {

    /// Gathers `recipes` and their photos into a package and writes it to a
    /// temp file ready to hand to `ShareLink`.
    static func export(recipes: [Recipe], cookbookName: String) throws -> URL {
        var photos: [String: Data] = [:]
        for recipe in recipes {
            if let data = RecipeUserPhotoStore.shared.photoData(for: recipe.id) {
                photos[recipe.id.uuidString] = data
            }
        }

        let package = CookbookPackage(cookbookName: cookbookName, recipes: recipes, photos: photos)
        let data = try JSONEncoder().encode(package)

        let name = sanitizedFileName(cookbookName)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(for: .kindredCookbook)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Decodes a package from a file URL — one handed in by `.onOpenURL` or a
    /// `.fileImporter` picker, both of which may need security-scoped access.
    static func load(from url: URL) throws -> CookbookPackage {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw CookbookPackageError.cannotAccessFile
        }
        do {
            return try JSONDecoder().decode(CookbookPackage.self, from: data)
        } catch {
            throw CookbookPackageError.notAKindredCookbook
        }
    }

    private static func sanitizedFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.isEmpty ? "Cookbook" : trimmed
        let invalid = CharacterSet(charactersIn: "/\\:")
        return cleaned.components(separatedBy: invalid).joined(separator: "-")
    }
}
