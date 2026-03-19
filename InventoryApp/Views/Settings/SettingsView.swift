import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorSchemePreference = "system"
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var webServer: LocalWebServer
    @State private var showClearAlert = false
    @State private var showSignOutAlert = false
    private let service = InventoryService.shared

    var body: some View {
        NavigationView {
            Form {

                // MARK: - Felhasználó
                Section("Felhasználó") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.15)).frame(width: 50, height: 50)
                            Image(systemName: auth.userID == "guest" ? "person.fill" : "applelogo")
                                .font(.title3).foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.userName.isEmpty ? "Vendég" : auth.userName)
                                .font(.headline)
                            Text(auth.userEmail.isEmpty ? (auth.userID == "guest" ? "Bejelentkezés nélkül" : auth.userID) : auth.userEmail)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if auth.userID == "guest" {
                        AppleSignInButton(
                            onSuccess: { cred in auth.signIn(credential: cred) },
                            onError: { _ in }
                        )
                        .frame(height: 44)
                        .cornerRadius(10)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } else {
                        Button(role: .destructive) { showSignOutAlert = true } label: {
                            Label("Kijelentkezés", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }

                // MARK: - iCloud
                Section("iCloud szinkronizálás") {
                    HStack {
                        Image(systemName: "icloud.fill").foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatikus szinkron").font(.subheadline)
                            Text(auth.userID == "guest" ? "Apple bejelentkezés szükséges" : "Aktív — minden eszközön szinkronizál")
                                .font(.caption).foregroundColor(auth.userID == "guest" ? .orange : .green)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Megjelenés
                Section("Megjelenés") {
                    HStack(spacing: 0) {
                        themeButton(title: "Világos", icon: "sun.max.fill", value: "light", color: .orange)
                        themeButton(title: "Sötét",   icon: "moon.fill",    value: "dark",  color: .indigo)
                        themeButton(title: "Rendszer", icon: "gearshape",   value: "system", color: .gray)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: - Web szerver
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Lokális web szerver").font(.subheadline.bold())
                                Text(webServer.isRunning ? webServer.serverURL : "Kikapcsolt állapot")
                                    .font(.caption).foregroundColor(webServer.isRunning ? .green : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { webServer.isRunning },
                                set: { on in
                                    if on { webServer.start() } else { webServer.stop() }
                                }
                            ))
                        }

                        if webServer.isRunning {
                            Divider()
                            VStack(spacing: 8) {
                                Text("Aktív token:").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 12) {
                                    Text(webServer.accessToken)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .tracking(6)
                                    Button {
                                        UIPasteboard.general.string = webServer.accessToken
                                    } label: {
                                        Image(systemName: "doc.on.doc").foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8).padding(.horizontal, 16)
                                .background(Color(.systemGray6)).cornerRadius(10)

                                Button {
                                    withAnimation { webServer.showTokenPopup = true }
                                } label: {
                                    Label("Token popup megjelenítése", systemImage: "bell.badge")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Web hozzáférés")
                } footer: {
                    Text("Böngészőből elérheted a leltárt a megadott IP-n. A token szükséges a belépéshez.")
                }

                // MARK: - Adatok
                Section("Adatok") {
                    LabeledContent("Termékek száma", value: "\(service.fetchProducts().count) db")
                    LabeledContent("Mozgások száma", value: "\(service.fetchTransactions(limit: 1000000).count) db")
                }

                // MARK: - Veszélyzóna
                Section("Veszélyzóna") {
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label("Összes adat törlése", systemImage: "trash.fill")
                    }
                }

                Section("Névjegy") {
                    LabeledContent("Verzió", value: "2.0.0")
                    LabeledContent("Build", value: "iCloud + Web szerver")
                }
            }
            .navigationTitle("Beállítások")
            .alert("Összes adat törlése", isPresented: $showClearAlert) {
                Button("Törlés", role: .destructive) {
                    service.fetchProducts().forEach { service.deleteProduct($0) }
                }
                Button("Mégsem", role: .cancel) {}
            } message: {
                Text("Ez a művelet nem vonható vissza.")
            }
            .alert("Kijelentkezés", isPresented: $showSignOutAlert) {
                Button("Kijelentkezés", role: .destructive) { auth.signOut() }
                Button("Mégsem", role: .cancel) {}
            } message: {
                Text("Biztosan kijelentkezel?")
            }
        }
    }

    private func themeButton(title: String, icon: String, value: String, color: Color) -> some View {
        let selected = colorSchemePreference == value
        return Button {
            colorSchemePreference = value
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                    .foregroundColor(selected ? .white : color)
                Text(title).font(.caption2)
                    .foregroundColor(selected ? .white : .primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(selected ? color : Color.clear)
            .cornerRadius(9)
        }
    }
}
