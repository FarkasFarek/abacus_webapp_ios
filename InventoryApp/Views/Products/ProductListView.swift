import SwiftUI

struct ProductListView: View {
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var showAddProduct = false
    @State private var showQRGenerator = false
    @State private var showLowStockOnly = false
    @State private var showInventoryList = false
    @State private var sortOrder: SortOrder = .name
    @State private var refreshID = UUID()
    private let service = InventoryService.shared

    enum SortOrder: String, CaseIterable {
        case name = "Nev"
        case stock = "Keszlet"
        case category = "Kategoria"
        case sku = "SKU"
    }

    var products: [ProductEntity] {
        var list = service.fetchProducts(searchText: searchText, category: selectedCategory)
        if showLowStockOnly { list = list.filter { $0.isLowStock || $0.isOutOfStock } }
        switch sortOrder {
        case .name:     list.sort { ($0.name ?? "") < ($1.name ?? "") }
        case .stock:    list.sort { $0.currentStock < $1.currentStock }
        case .category: list.sort { ($0.category ?? "") < ($1.category ?? "") }
        case .sku:      list.sort { ($0.sku ?? "") < ($1.sku ?? "") }
        }
        return list
    }

    var categories: [String] { service.fetchCategories() }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Kategoria filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Mind", isSelected: selectedCategory.isEmpty) {
                            selectedCategory = ""
                        }
                        ForEach(categories, id: \.self) { cat in
                            FilterChip(title: cat, isSelected: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? "" : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGroupedBackground))

                // Leltar gyorsgomb banner
                Button {
                    showInventoryList = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Leltar generalas")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Text("Lista alapu leszamolas, QR nelkul")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.07))
                }

                Divider()

                if products.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text(searchText.isEmpty ? "Nincsenek termekek" : "Nincs talalat")
                            .font(.title2.bold())
                        Text(searchText.isEmpty ? "Adj hozza termeket a + gombbal" : "Probald mas feltetellel")
                            .font(.subheadline).foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Button { showAddProduct = true } label: {
                                Label("Termek hozzaadasa", systemImage: "plus.circle.fill")
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                            }.buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }.padding()
                } else {
                    List {
                        ForEach(products) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                ProductRowView(product: product)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { products[$0] }.forEach { service.deleteProduct($0) }
                            refreshID = UUID()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Termekek (\(products.count))")
            .searchable(text: $searchText, prompt: "Kereses nevben, SKU-ban...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Rendezes", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        Divider()
                        Toggle("Csak alacsony keszlet", isOn: $showLowStockOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showQRGenerator = true } label: { Image(systemName: "qrcode") }
                        Button { showAddProduct = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showAddProduct, onDismiss: { refreshID = UUID() }) {
                AddProductView()
            }
            .sheet(isPresented: $showQRGenerator) {
                QRGeneratorView()
            }
            .sheet(isPresented: $showInventoryList, onDismiss: { refreshID = UUID() }) {
                InventoryListCountView()
            }
        }
        .id(refreshID)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ProductRowView: View {
    let product: ProductEntity
    private var stockColor: Color {
        product.isOutOfStock ? .red : product.isLowStock ? .orange : .green
    }
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(stockColor.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "shippingbox.fill").foregroundColor(stockColor).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name ?? "").font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    Text(product.sku ?? "").font(.caption).foregroundColor(.secondary)
                    if let cat = product.category, !cat.isEmpty {
                        Text("- \(cat)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(fmtQ(product.currentStock)).font(.title3.bold()).foregroundColor(stockColor)
                Text(product.unit ?? "db").font(.caption).foregroundColor(.secondary)
                if product.isLowStock || product.isOutOfStock {
                    Text(product.stockStatus.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(stockColor.opacity(0.15))
                        .foregroundColor(stockColor)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private func fmtQ(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
}
