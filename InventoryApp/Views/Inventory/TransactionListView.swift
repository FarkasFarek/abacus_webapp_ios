import SwiftUI

struct TransactionListView: View {
    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    private let service = InventoryService.shared

    var transactions: [TransactionEntity] {
        var list = service.fetchTransactions(limit: 500)
        if let t = selectedType { list = list.filter { $0.transactionType == t } }
        if !searchText.isEmpty {
            list = list.filter {
                ($0.productName ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.note ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.deliveryNote ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Mind", isSelected: selectedType == nil) { selectedType = nil }
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            FilterChip(title: t.label, isSelected: selectedType == t) {
                                selectedType = selectedType == t ? nil : t
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))
                List {
                    ForEach(transactions) { tx in TransactionRowView(transaction: tx) }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if transactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.left.arrow.right.circle").font(.system(size: 50)).foregroundColor(.secondary.opacity(0.3))
                            Text("Nincs mozgás").font(.title3).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mozgások (\(transactions.count))")
            .searchable(text: $searchText, prompt: "Termék neve, megjegyzés...")
        }
    }
}

struct TransactionRowView: View {
    let transaction: TransactionEntity
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(transaction.transactionType.color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: transaction.transactionType.icon)
                    .foregroundColor(transaction.transactionType.color).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.productName ?? "").font(.subheadline.bold()).lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.transactionType.label).font(.caption)
                        .foregroundColor(transaction.transactionType.color)
                    if let dn = transaction.deliveryNote, !dn.isEmpty {
                        Text("· \(dn)").font(.caption).foregroundColor(.secondary)
                    }
                    if let note = transaction.note, !note.isEmpty {
                        Text("· \(note)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(fmtQ(transaction.quantity)).font(.subheadline.bold())
                    .foregroundColor(transaction.transactionType.color)
                if let ts = transaction.timestamp {
                    Text(ts, style: .date).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private func fmtQ(_ v: Double) -> String { v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v) }
