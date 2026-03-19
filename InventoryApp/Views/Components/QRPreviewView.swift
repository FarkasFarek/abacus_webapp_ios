import SwiftUI

struct QRPreviewView: View {
    let content: String
    let productName: String
    let sku: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(productName).font(.title2.bold())
                QRCodeView(content: content, size: 240)
                    .padding(20).background(Color.white).cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8)
                VStack(spacing: 6) {
                    Text("SKU: \(sku)").font(.subheadline).foregroundColor(.secondary)
                    Text(content).font(.caption2).foregroundColor(.secondary).lineLimit(2)
                }
                Button(action: printQR) {
                    Label("Nyomtatás (AirPrint)", systemImage: "printer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationTitle("QR-kód")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bezár") { dismiss() } }
            }
        }
    }

    private func printQR() {
        guard let img = QRCodeService.shared.generateQRCode(from: content, size: 600) else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = productName; info.outputType = .photo
        let c = UIPrintInteractionController.shared
        c.printInfo = info; c.printingItem = img
        c.present(animated: true)
    }
}
