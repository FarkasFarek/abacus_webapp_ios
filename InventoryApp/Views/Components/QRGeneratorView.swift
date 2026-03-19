import SwiftUI

struct QRGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    private let service = InventoryService.shared

    var body: some View {
        NavigationView {
            List(service.fetchProducts()) { product in
                VStack(alignment: .leading, spacing: 12) {
                    Text(product.name ?? "").font(.headline)
                    Text("SKU: \(product.sku ?? "")").font(.caption).foregroundColor(.secondary)
                    HStack {
                        Spacer()
                        QRCodeView(content: QRCodeService.shared.generateProductQRContent(sku: product.sku ?? ""), size: 120)
                        Spacer()
                    }
                    Button(action: { printQR(product: product) }) {
                        Label("Nyomtatás", systemImage: "printer").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("QR-kódok")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bezár") { dismiss() } }
            }
        }
    }

    private func printQR(product: ProductEntity) {
        let sku = product.sku ?? ""
        let content = QRCodeService.shared.generateProductQRContent(sku: sku)
        guard let img = QRCodeService.shared.generateQRCode(from: content, size: 400) else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = product.name ?? "QR"
        printInfo.outputType = .photo
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = img
        controller.present(animated: true)
    }
}

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200
    var body: some View {
        if let img = QRCodeService.shared.generateQRCode(from: content, size: size * 3) {
            Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "xmark.circle").frame(width: size, height: size)
        }
    }
}
