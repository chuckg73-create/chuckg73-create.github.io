import Foundation
import Vision
import UIKit

/// Identifies likely food ingredients in a photo of a fridge or pantry, entirely
/// on-device using Apple's Vision framework. No image ever leaves the phone.
///
/// It runs Vision's built-in image classifier (`VNClassifyImageRequest`) to get
/// candidate labels, then filters them against a curated food vocabulary and maps
/// each surviving label to an `Ingredient` with a grocery category. This keeps
/// the recogniser dependency-free (no bundled Core ML model) while staying fully
/// private and offline.
struct VisionIngredientRecognizer {

    /// Minimum Vision confidence to accept a label.
    var minimumConfidence: Float = 0.10
    /// Cap on how many ingredients to return from a single photo.
    var maxResults: Int = 18

    enum RecognizerError: LocalizedError {
        case invalidImage
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "That image couldn't be read. Try taking the photo again."
            case .requestFailed(let m): return "On-device recognition failed: \(m)"
            }
        }
    }

    /// Recognise ingredients in a `UIImage`, off the main thread.
    func recognizeIngredients(in image: UIImage) async throws -> [Ingredient] {
        guard let cgImage = image.normalizedCGImage() else {
            throw RecognizerError.invalidImage
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let ingredients = try classify(cgImage: cgImage, orientation: image.cgOrientation)
                    continuation.resume(returning: ingredients)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Vision

    private func classify(cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> [Ingredient] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw RecognizerError.requestFailed(error.localizedDescription)
        }

        let observations = (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }

        // Merge duplicate foods (Vision can emit close synonyms), keeping the
        // highest confidence for each canonical name.
        var best: [String: (name: String, category: IngredientCategory, confidence: Float)] = [:]
        for observation in observations {
            guard let match = FoodVocabulary.match(observation.identifier) else { continue }
            let key = match.name.lowercased()
            if let existing = best[key], existing.confidence >= observation.confidence { continue }
            best[key] = (match.name, match.category, observation.confidence)
        }

        return best.values
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxResults)
            .map { Ingredient(
                name: $0.name,
                category: $0.category,
                confidence: Double($0.confidence)
            )}
    }
}

// MARK: - UIImage helpers

extension UIImage {
    /// A CGImage with orientation baked in and a sane max dimension for Vision.
    func normalizedCGImage(maxDimension: CGFloat = 1600) -> CGImage? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let redrawn = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return redrawn.cgImage
    }

    var cgOrientation: CGImagePropertyOrientation {
        CGImagePropertyOrientation(imageOrientation)
    }

    /// A downscaled JPEG suitable for uploading to a vision model.
    func jpegForUpload(maxDimension: CGFloat = 1024, quality: CGFloat = 0.6) -> Data? {
        if let cg = normalizedCGImage(maxDimension: maxDimension) {
            return UIImage(cgImage: cg).jpegData(compressionQuality: quality)
        }
        return jpegData(compressionQuality: quality)
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
