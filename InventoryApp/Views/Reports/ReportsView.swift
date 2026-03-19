import SwiftUI

struct ReportsView: View {
    @State private var shareURL: URL?
    @State private var showShare = false
    private let service = InventoryService.shared
    private let export = ExportService.shared

    var transactions: [TransactionEntity] { service.fetchTransactions(limit: 500) }

    var inCount: Int { transactions.filter { $0.transactionType == .stockIn }.count }
    var outCount: Int { transactions.filter { $0.transactionType == .stockOut }.count }

    var body: some View {
        NavigationView {
            List {
                Section("Összesítő") {
                    LabeledContent("Összes bevét mozgás", value: "\(inCount) db")
                    LabeledContent("Összes kivét mozgás", value: "\(outCount) db")
                    LabeledContent("Összes mozgás", value: "\(transactions.count) db")
                }
                Section("Export") {
                    Button {
                        if let url = export.exportProductsCSV() {
                            shareURL = url; showShare = true
                        }
                    } label: {
                        Label("Termékek exportálása (CSV)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        if let url = export.exportTransactionsCSV() {
                            shareURL = url; showShare = true
                        }
                    } label: {
                        Label("Mozgások exportálása (CSV)", systemImage: "square.and.arrow.up")
                    }
                }
                Section("Legutóbbi 20 mozgás") {
                    ForEach(transactions.prefix(20)) { tx in
                        TransactionRowView(transaction: tx)
                    }
                }
            }
            .navigationTitle("Riportok")
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
