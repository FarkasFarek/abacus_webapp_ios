import Foundation
import UIKit

class ExportService {
    static let shared = ExportService()
    private let service = InventoryService.shared

    func exportProductsCSV() -> URL? {
        var csv = "Nev,SKU,Vonalkod,Kategoria,Keszlet,Egyseg,Min.keszlet,Ar,Helyszin\n"
        for p in service.fetchProducts() {
            csv += "\"\(p.name ?? "")\",\"\(p.sku ?? "")\",\"\(p.barcode ?? "")\",\"\(p.category ?? "")\","
            csv += "\(fmtQ(p.currentStock)),\"\(p.unit ?? "")\",\(fmtQ(p.minStock)),\(fmtQ(p.price)),\"\(p.location ?? "")\"\n"
        }
        return writeTemp(csv, filename: "keszlet_\(today()).csv")
    }

    func exportTransactionsCSV() -> URL? {
        var csv = "Datum,Termek,Tipus,Mennyiseg,Megjegyzes,Szallitolevel,Felhasznalo\n"
        for t in service.fetchTransactions(limit: 10000) {
            let date = t.timestamp.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            csv += "\"\(date)\",\"\(t.productName ?? "")\",\"\(t.transactionType.label)\","
            csv += "\(fmtQ(t.quantity)),\"\(t.note ?? "")\",\"\(t.deliveryNote ?? "")\",\"\(t.user ?? "")\"\n"
        }
        return writeTemp(csv, filename: "mozgasok_\(today()).csv")
    }

    private func fmtQ(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
    }

    private func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private func writeTemp(_ content: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
