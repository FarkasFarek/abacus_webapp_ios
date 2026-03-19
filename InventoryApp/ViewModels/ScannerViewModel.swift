import Foundation
import Combine

class ScannerViewModel: ObservableObject {
    @Published var showNotFound = false
    @Published var lastScannedCode = ""

    // Megtartjuk visszafele kompatibilitas miatt (ProductDetailView stb. nem hasznalja)
    @Published var foundProduct: ProductEntity?
    @Published var shouldReset = false

    private let service = InventoryService.shared

    /// Uj callback-alapu scan: a talalt termeket azonnal visszaadja
    func handleScan(code: String, completion: @escaping (ProductEntity?) -> Void) {
        lastScannedCode = code
        let parsed = QRCodeService.shared.parseQRContent(code)
        var product: ProductEntity?
        if parsed.type == .product, let sku = parsed.sku {
            product = service.fetchProducts(searchText: sku).first(where: { $0.sku == sku })
        }
        if product == nil {
            product = service.findProduct(byBarcode: code)
        }
        DispatchQueue.main.async {
            if let p = product {
                self.foundProduct = p
                self.showNotFound = false
                completion(p)
            } else {
                self.foundProduct = nil
                self.showNotFound = true
                completion(nil)
            }
        }
    }

    /// Regi, @Published alapu scan (megtartva visszafele kompatibilitas miatt)
    func handleScan(code: String) {
        handleScan(code: code) { _ in }
    }

    func recordTransaction(product: ProductEntity, type: TransactionType,
                           quantity: Double, note: String, deliveryNote: String = "") {
        let user = UserDefaults.standard.string(forKey: "currentUser") ?? ""
        service.recordTransaction(product: product, type: type, quantity: quantity,
                                  note: note, deliveryNote: deliveryNote, user: user)
        resetScan()
    }

    func resetScan() {
        DispatchQueue.main.async {
            self.foundProduct = nil
            self.showNotFound = false
            self.shouldReset = true
        }
    }
}
