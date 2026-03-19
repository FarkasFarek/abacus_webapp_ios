import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

class QRCodeService {
    static let shared = QRCodeService()

    func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let sx = size / output.extent.size.width
        let sy = size / output.extent.size.height
        let scaled = output.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    func generateProductQRContent(sku: String) -> String { "INV:\(sku)" }

    func parseQRContent(_ content: String) -> QRParseResult {
        if content.hasPrefix("INV:") {
            let sku = String(content.dropFirst(4))
            return QRParseResult(type: .product, sku: sku, rawContent: content)
        }
        return QRParseResult(type: .unknown, sku: nil, rawContent: content)
    }
}

struct QRParseResult {
    enum QRType { case product, unknown }
    let type: QRType
    let sku: String?
    let rawContent: String
}
