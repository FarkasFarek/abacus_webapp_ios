import SwiftUI

struct ScannerView: View {
    @StateObject private var vm = ScannerViewModel()
    @State private var scannedProduct: ProductEntity? = nil
    @State private var showTransaction = false
    @State private var showAddProduct = false
    @State private var scanning = true

    var body: some View {
        NavigationView {
            ZStack {
                if scanning {
                    QRCameraView { code in
                        vm.handleScan(code: code) { found in
                            if let product = found {
                                scannedProduct = product
                                scanning = false
                                showTransaction = true
                            } else {
                                scanning = false
                            }
                        }
                    }
                    VStack {
                        Spacer()
                        Text("QR-kod vagy vonalkod ele tartsd a kamerat")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.bottom, 40)
                    }
                } else if vm.showNotFound {
                    NotFoundView(
                        scannedCode: vm.lastScannedCode,
                        onRetry: {
                            vm.showNotFound = false
                            scanning = true
                        },
                        onAddNew: {
                            showAddProduct = true
                        }
                    )
                }
            }
            .navigationTitle("Beolvasas")
            .sheet(isPresented: $showAddProduct, onDismiss: {
                vm.showNotFound = false
                scanning = true
            }) {
                AddProductView(prefillBarcode: vm.lastScannedCode)
            }
            .sheet(isPresented: $showTransaction, onDismiss: {
                scannedProduct = nil
                vm.showNotFound = false
                scanning = true
            }) {
                if let p = scannedProduct {
                    QuantityInputView(product: p) { type, qty, note, dn in
                        let user = UserDefaults.standard.string(forKey: "currentUser") ?? ""
                        InventoryService.shared.recordTransaction(
                            product: p, type: type, quantity: qty,
                            note: note, deliveryNote: dn, user: user
                        )
                        showTransaction = false
                    }
                }
            }
        }
    }
}

struct QRScannerSheetView: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            QRCameraView(onScan: { code in onScan(code); dismiss() })
                .navigationTitle("QR beolvasas")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Megsem") { dismiss() }
                    }
                }
        }
    }
}

struct NotFoundView: View {
    let scannedCode: String
    let onRetry: () -> Void
    let onAddNew: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "questionmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)

            Text("Ismeretlen kod").font(.title2.bold())

            Text(scannedCode)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Ez a termek nem talalhato a keszletben")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    onAddNew()
                } label: {
                    Label("Felvetel uj termekkent", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Ujra probalom") {
                    onRetry()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
    }
}
