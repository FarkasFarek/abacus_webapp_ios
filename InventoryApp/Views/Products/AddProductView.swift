import SwiftUI

struct AddProductView: View {
    var editProduct: ProductEntity? = nil
    var prefillBarcode: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var sku = ""
    @State private var barcode = ""
    @State private var category = ""
    @State private var unit = "db"
    @State private var minStock = ""
    @State private var price = ""
    @State private var location = ""
    @State private var note = ""
    @State private var showScanner = false
    private let service = InventoryService.shared
    let units = ["db", "kg", "liter", "m", "csomag", "doboz", "készlet"]

    var body: some View {
        NavigationView {
            Form {
                Section("Alapadatok") {
                    TextField("Termék neve *", text: $name)
                    HStack {
                        TextField("SKU *", text: $sku)
                        Button { showScanner = true } label: {
                            Image(systemName: "qrcode.viewfinder").foregroundColor(.blue)
                        }
                    }
                    TextField("Vonalkód / QR tartalom", text: $barcode)
                    TextField("Kategória", text: $category)
                    Picker("Mértékegység", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0) }
                    }
                }
                Section("Készlet és ár") {
                    TextField("Min. készletszint", text: $minStock).keyboardType(.decimalPad)
                    TextField("Egységár (Ft)", text: $price).keyboardType(.decimalPad)
                    TextField("Helyszín / Raktárhely", text: $location)
                }
                Section("Megjegyzés") {
                    TextField("Opcionális", text: $note, axis: .vertical).lineLimit(3)
                }
                if !sku.isEmpty {
                    Section("QR-kód előnézet") {
                        HStack {
                            Spacer()
                            QRCodeView(content: QRCodeService.shared.generateProductQRContent(sku: sku), size: 160)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(editProduct == nil ? "Új termék" : "Termék szerkesztése")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Mégsem") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mentés") { save() }.disabled(name.isEmpty || sku.isEmpty)
                }
            }
            .onAppear {
                if let p = editProduct { populate(from: p) }
                applyPrefill()
            }
            .sheet(isPresented: $showScanner) {
                QRScannerSheetView { code in
                    let parsed = QRCodeService.shared.parseQRContent(code)
                    sku = parsed.sku ?? code
                    barcode = code
                    showScanner = false
                }
            }
        }
    }

    private func populate(from p: ProductEntity) {
        name = p.name ?? ""; sku = p.sku ?? ""; barcode = p.barcode ?? ""
        category = p.category ?? ""; unit = p.unit ?? "db"
        minStock = fmtQ(p.minStock); price = fmtQ(p.price)
        location = p.location ?? ""; note = p.note ?? ""
    }

    private func applyPrefill() {
        guard editProduct == nil, !prefillBarcode.isEmpty else { return }
        barcode = prefillBarcode
        if sku.isEmpty { sku = prefillBarcode }
    }

    private func save() {
        let min = Double(minStock) ?? 0
        let pr = Double(price) ?? 0
        let bc = barcode.isEmpty ? sku : barcode
        if let p = editProduct {
            service.updateProduct(p, name: name, sku: sku, barcode: bc, category: category,
                                  unit: unit, minStock: min, price: pr, location: location, note: note)
        } else {
            service.addProduct(name: name, sku: sku, barcode: bc, category: category,
                               unit: unit, minStock: min, price: pr, location: location, note: note)
        }
        dismiss()
    }
}

private func fmtQ(_ v: Double) -> String { v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v) }
