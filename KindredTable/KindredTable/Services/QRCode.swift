import UIKit
import CoreImage.CIFilterBuiltins

/// On-device QR generation (CoreImage). Nothing leaves the phone.
enum QRCode {
    static func image(from string: String, scale: CGFloat = 12) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
