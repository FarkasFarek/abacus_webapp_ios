import SwiftUI

struct ProductDetailView: View {
    let product: ProductEntity
    @State private var showEdit = false
    @State private var showQR = false
    @State private var showTransaction = false
    @State private var transactionType: TransactionType = .stockIn
    @State private var showDeleteAlert = false
    @State private var refreshID = UUID()
    @Environment(\.dismiss) private var dismiss
    private let service = InventoryService.shared

    var transactions: [TransactionEntity] { service.fetchTransactions(for: product, limit: 30) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        StatCircle(value: fmtQ(product.currentStock), label: "Készlet", unit: product.unit ?? "", color: product.stockStatus.color)
                        StatCircle(value: fmtQ(product.minStock), label: "Min.", unit: product.unit ?? "", color: .secondary)
                        StatCircle(value: fmtVal(product.currentStock * product.price), label: "Érték", unit: "Ft", color: .blue)
                    }
                    .frame(maxWidth: .infinity)
                    if product.isOutOfStock {
                        Label("Elfogyott!", systemImage: "exclamationmark.octagon.fill")
                            .foregroundColor(.red).font(.subheadline.bold())
                    } else if product.isLowStock {
                        Label("Alacsony készlet", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange).font(.subheadline.bold())
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Termékinformáció") {
                InfoRow(label: "SKU", value: product.sku ?? "-")
                InfoRow(label: "Vonalkód / QR", value: product.barcode ?? "-")
                InfoRow(label: "Kategória", value: product.category ?? "-")
                InfoRow(label: "Egység", value: product.unit ?? "-")
                InfoRow(label: "Min. készlet", value: "\(fmtQ(product.minStock)) \(product.unit ?? "")")
                InfoRow(label: "Egységár", value: "\(fmtQ(product.price)) Ft")
                if let loc = product.location, !loc.isEmpty { InfoRow(label: "Helyszín", value: loc) }
                if let note = product.note, !note.isEmpty { InfoRow(label: "Megjegyzés", value: note) }
                if let date = product.createdAt {
                    InfoRow(label: "Létrehozva", value: date.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Gyors műveletek") {
                HStack(spacing: 8) {
                    ForEach([TransactionType.stockIn, .stockOut, .inventory, .waste], id: \.self) { t in
                        Button {
                            transactionType = t
                            showTransaction = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: t.icon).font(.title3).foregroundColor(t.color)
                                Text(t.label).font(.caption2).foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(t.color.opacity(0.1)).cornerRadius(10)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                Button { showQR = true } label: {
                    Label("QR-kód megtekintése / nyomtatás", systemImage: "qrcode")
                }
            }

            Section("Utolsó 30 mozgás") {
                if transactions.isEmpty {
                    Text("Még nincs mozgás").foregroundColor(.secondary).italic()
                } else {
                    ForEach(transactions) { tx in TransactionRowView(transaction: tx) }
                }
            }

            Section {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Termék törlése", systemImage: "trash").frame(maxWidth: .infinity)
                }
            }
        }
        .id(refreshID)
        .listStyle(.insetGrouped)
        .navigationTitle(product.name ?? "Termék")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "pencil.circle") }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { refreshID = UUID() }) { AddProductView(editProduct: product) }
        .sheet(isPresented: $showQR) {
            QRPreviewView(content: QRCodeService.shared.generateProductQRContent(sku: product.sku ?? ""),
                          productName: product.name ?? "", sku: product.sku ?? "")
        }
        .sheet(isPresented: $showTransaction, onDismiss: { refreshID = UUID() }) {
            QuantityInputView(product: product, initialType: transactionType) { type, qty, note, dn in
                service.recordTransaction(product: product, type: type, quantity: qty, note: note, deliveryNote: dn)
                showTransaction = false
                refreshID = UUID()
            }
        }
        .alert("Törlés megerősítése", isPresented: $showDeleteAlert) {
            Button("Törlés", role: .destructive) { service.deleteProduct(product); dismiss() }
            Button("Mégsem", role: .cancel) {}
        } message: {
            Text("Biztosan törli a(z) \(product.name ?? "") terméket?")
        }
    }
}

struct StatCircle: View {
    let value: String; let label: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 4).frame(width: 72, height: 72)
                VStack(spacing: 0) {
                    Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.6)
                    Text(unit).font(.caption2).foregroundColor(.secondary)
                }
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct QuickActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundColor(color)
                Text(title).font(.caption2).foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(color.opacity(0.1)).cornerRadius(10)
        }
    }
}

private func fmtQ(_ v: Double) -> String { v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v) }
private func fmtVal(_ v: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "0"
}
