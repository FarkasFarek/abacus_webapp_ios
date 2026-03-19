import SwiftUI

struct QuantityInputView: View {
    let product: ProductEntity
    var initialType: TransactionType = .stockIn
    var onConfirm: (TransactionType, Double, String, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedType: TransactionType = .stockIn
    @State private var quantityText = ""
    @State private var note = ""
    @State private var deliveryNote = ""

    private var parsedQty: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    private var expectedStock: Double {
        guard let qty = parsedQty, qty >= 0 else { return product.currentStock }
        switch selectedType {
        case .stockIn:                return product.currentStock + qty
        case .inventory, .correction: return qty
        case .stockOut, .waste:       return max(0, product.currentStock - qty)
        }
    }

    private var diff: Double { expectedStock - product.currentStock }
    private var isInventory: Bool { selectedType == .inventory }
    private var isValid: Bool { (parsedQty ?? -1) >= 0 && !quantityText.isEmpty }

    // A 4 muveleti tipus amit a scanner es a detail nezet is hasznal
    private let types: [TransactionType] = [.stockIn, .stockOut, .waste, .inventory]

    var body: some View {
        NavigationView {
            Form {

                // MARK: Muvelet tipusa
                Section("Muvelet tipusa") {
                    HStack(spacing: 6) {
                        ForEach(types, id: \.self) { t in
                            Button {
                                selectedType = t
                                quantityText = ""
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: t.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedType == t ? .white : t.color)
                                    Text(t.label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(selectedType == t ? .white : .primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(selectedType == t ? t.color : t.color.opacity(0.12))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                // MARK: Termek info
                Section("Termek") {
                    LabeledContent("Nev", value: product.name ?? "")
                    if let sku = product.sku, !sku.isEmpty {
                        LabeledContent("SKU", value: sku)
                    }
                    LabeledContent("Aktualis keszlet") {
                        Text("\(fmtQQ(product.currentStock)) \(product.unit ?? "")").fontWeight(.bold)
                            .foregroundColor(product.stockStatus.color)
                    }
                }

                // MARK: Mennyiseg
                Section {
                    if isInventory {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Leszamolt mennyiseg (tenyleges keszlet)")
                                .font(.caption).foregroundColor(.secondary)
                            TextField("pl. 18", text: $quantityText)
                                .keyboardType(.decimalPad)
                                .font(.title2.bold())
                        }
                    } else {
                        let placeholder: String = {
                            switch selectedType {
                            case .stockIn:  return "Bevetelezett mennyiseg"
                            case .stockOut: return "Kivett mennyiseg"
                            case .waste:    return "Selejt mennyiseg"
                            default:        return "Mennyiseg"
                            }
                        }()
                        TextField(placeholder, text: $quantityText)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                    }
                } header: {
                    Text(isInventory ? "Leltar" : "Mennyiseg")
                }

                // MARK: Osszefoglalo
                if !quantityText.isEmpty, parsedQty != nil {
                    Section("Osszefoglalo") {
                        LabeledContent("Elotte") {
                            Text("\(fmtQQ(product.currentStock)) \(product.unit ?? "")")
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("Utana") {
                            Text("\(fmtQQ(expectedStock)) \(product.unit ?? "")")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        if diff != 0 {
                            LabeledContent("Valtozas") {
                                let sign = diff > 0 ? "+" : ""
                                Text("\(sign)\(fmtQQ(diff)) \(product.unit ?? "")")
                                    .fontWeight(.bold)
                                    .foregroundColor(diff < 0 ? .red : .orange)
                            }
                        }
                    }
                }

                // MARK: Dokumentacio
                Section("Dokumentacio") {
                    if selectedType == .stockIn {
                        TextField("Szallitolevel szam (opcionalis)", text: $deliveryNote)
                    }
                    TextField("Megjegyzes (opcionalis)", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle(selectedType.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Megsem") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rogzit") {
                        if let qty = parsedQty, isValid {
                            onConfirm(selectedType, qty, note, deliveryNote)
                        }
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                }
            }
            .onAppear { selectedType = initialType }
        }
    }
}

private func fmtQQ(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.3f", v)
}
