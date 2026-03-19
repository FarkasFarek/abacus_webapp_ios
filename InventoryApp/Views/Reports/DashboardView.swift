import SwiftUI

struct DashboardView: View {
    @State private var stats = DashboardStats(totalProducts: 0, lowStockCount: 0, totalValue: 0, todayTransactions: 0, lowStockProducts: [])
    @State private var refreshID = UUID()
    private let service = InventoryService.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Termékek", value: "\(stats.totalProducts)", icon: "shippingbox.fill", color: .blue)
                        StatCard(title: "Alacsony készlet", value: "\(stats.lowStockCount)", icon: "exclamationmark.triangle.fill", color: stats.lowStockCount > 0 ? .orange : .green)
                        StatCard(title: "Készlet értéke", value: fmtVal(stats.totalValue), icon: "creditcard.fill", color: .purple)
                        StatCard(title: "Mai mozgások", value: "\(stats.todayTransactions)", icon: "arrow.left.arrow.right", color: .teal)
                    }
                    .padding(.horizontal)

                    if !stats.lowStockProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alacsony készletű termékek")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(stats.lowStockProducts) { p in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(p.isOutOfStock ? .red : .orange)
                                    Text(p.name ?? "").font(.subheadline)
                                    Spacer()
                                    Text("\(fmtQ(p.currentStock)) \(p.unit ?? "")").font(.subheadline.bold())
                                        .foregroundColor(p.isOutOfStock ? .red : .orange)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }

                    let recent = service.fetchTransactions(limit: 5)
                    if !recent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Legutóbbi mozgások")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(recent) { tx in
                                TransactionRowView(transaction: tx)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Áttekintés")
            .onAppear { reload() }
            .id(refreshID)
        }
    }

    private func reload() { stats = service.dashboardStats() }

    private func fmtVal(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "0") + " Ft"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private func fmtQ(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
}
