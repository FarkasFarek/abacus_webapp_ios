import SwiftUI
import UIKit

struct InventoryListCountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [CountRow] = []
    @State private var searchText = ""
    @State private var showSaveAlert = false
    @State private var savedCount = 0
    private let service = InventoryService.shared

    struct CountRow: Identifiable {
        let id: UUID
        let product: ProductEntity
        var countedText: String = ""

        var counted: Double? {
            let s = countedText.replacingOccurrences(of: ",", with: ".")
            return Double(s)
        }
        var diff: Double {
            guard let c = counted else { return 0 }
            return c - product.currentStock
        }
        var hasChange: Bool {
            guard let c = counted else { return false }
            return c != product.currentStock
        }
    }

    var filteredRows: [CountRow] {
        guard !searchText.isEmpty else { return rows }
        return rows.filter {
            ($0.product.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.product.sku  ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.product.category ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var changedCount: Int { rows.filter { $0.hasChange }.count }

    var body: some View {
        NavigationView {
            List {
                if changedCount > 0 {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("\(changedCount) termeknel van valtozas")
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Termekek (\(rows.count) db)") {
                    ForEach(filteredRows) { row in
                        CountRowView(
                            row: row,
                            onUpdate: { newText in
                                if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                                    rows[idx].countedText = newText
                                }
                            }
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Szures nev, SKU, kategoria alapjan")
            .navigationTitle("Leltar lista")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Megsem") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Nyomtatas gomb
                        Button {
                            printInventoryList()
                        } label: {
                            Image(systemName: "printer")
                        }
                        // Mentes gomb
                        Button("Mentes") {
                            saveAll()
                        }
                        .fontWeight(.bold)
                        .disabled(changedCount == 0)
                    }
                }
            }
            .alert("Leltar rogzitve", isPresented: $showSaveAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(savedCount) termek keszlete frissult. Az elterereseket a rendszer automatikusan kiszamolta.")
            }
            .onAppear { loadRows() }
        }
    }

    private func loadRows() {
        let products = service.fetchProducts()
        rows = products.map { CountRow(id: $0.id ?? UUID(), product: $0) }
    }

    private func saveAll() {
        var count = 0
        for row in rows {
            guard row.hasChange, let counted = row.counted else { continue }
            let before = row.product.currentStock
            let diff = counted - before
            let sign = diff > 0 ? "+" : ""
            let noteStr = "Leltar lista | Elotte: \(fmtQI(before)) | Utana: \(fmtQI(counted)) | Elteres: \(sign)\(fmtQI(diff))"
            service.recordTransaction(
                product: row.product,
                type: .inventory,
                quantity: counted,
                note: noteStr
            )
            count += 1
        }
        savedCount = count
        showSaveAlert = true
    }

    private func printInventoryList() {
        let html = buildPrintHTML()
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Leltar lista"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printFormatter = formatter
        printController.present(animated: true)
    }

    private func buildPrintHTML() -> String {
        let dateStr = Date().formatted(date: .abbreviated, time: .shortened)
        var rowsHTML = ""
        for row in rows {
            let name = row.product.name ?? ""
            let sku  = row.product.sku  ?? ""
            let unit = row.product.unit ?? ""
            let stock = fmtQI(row.product.currentStock)
            let counted = row.counted != nil ? fmtQI(row.counted!) : ""
            let diffStr: String
            let diffColor: String
            if row.hasChange {
                let sign = row.diff > 0 ? "+" : ""
                diffStr = "\(sign)\(fmtQI(row.diff)) \(unit)"
                diffColor = row.diff < 0 ? "red" : "orange"
            } else {
                diffStr = "-"
                diffColor = "black"
            }
            rowsHTML += """
            <tr>
                <td>\(name)</td>
                <td>\(sku)</td>
                <td style='text-align:center'>\(stock) \(unit)</td>
                <td style='text-align:center'>\(counted.isEmpty ? "____" : counted + " " + unit)</td>
                <td style='text-align:center; color:\(diffColor); font-weight:bold'>\(diffStr)</td>
            </tr>
            """
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset='utf-8'>
        <style>
            body { font-family: -apple-system, sans-serif; font-size: 12px; margin: 20px; }
            h1 { font-size: 18px; margin-bottom: 4px; }
            .date { color: gray; font-size: 11px; margin-bottom: 16px; }
            table { width: 100%; border-collapse: collapse; }
            th { background: #f0f0f0; padding: 8px; text-align: left; border-bottom: 2px solid #ccc; }
            td { padding: 7px 8px; border-bottom: 1px solid #eee; }
            tr:nth-child(even) { background: #fafafa; }
        </style>
        </head>
        <body>
        <h1>Leltar lista</h1>
        <div class='date'>Generalva: \(dateStr) | Termekek szama: \(rows.count) db</div>
        <table>
            <thead>
                <tr>
                    <th>Termek neve</th>
                    <th>SKU</th>
                    <th style='text-align:center'>Rendszer keszlet</th>
                    <th style='text-align:center'>Leszamolt</th>
                    <th style='text-align:center'>Elteres</th>
                </tr>
            </thead>
            <tbody>
                \(rowsHTML)
            </tbody>
        </table>
        </body>
        </html>
        """
    }
}

struct CountRowView: View {
    let row: InventoryListCountView.CountRow
    let onUpdate: (String) -> Void
    @State private var localText: String = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.product.name ?? "")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let sku = row.product.sku, !sku.isEmpty {
                        Text(sku).font(.caption).foregroundColor(.secondary)
                    }
                    if let cat = row.product.category, !cat.isEmpty {
                        Text("- " + cat).font(.caption).foregroundColor(.secondary)
                    }
                }
                if row.hasChange {
                    let sign = row.diff > 0 ? "+" : ""
                    HStack(spacing: 4) {
                        Image(systemName: row.diff < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.caption)
                        Text("Elteres: \(sign)\(fmtQI(row.diff)) \(row.product.unit ?? "")")
                            .font(.caption.bold())
                    }
                    .foregroundColor(row.diff < 0 ? .red : .orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                TextField("-", text: $localText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onChange(of: localText) { onUpdate(localText) }
                Text("akt: \(fmtQI(row.product.currentStock)) \(row.product.unit ?? "")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear { localText = row.countedText }
    }
}

private func fmtQI(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
}
