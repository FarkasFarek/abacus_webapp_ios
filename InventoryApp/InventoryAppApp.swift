import SwiftUI
import CoreData

@main
struct InventoryAppApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var auth = AuthService.shared
    @StateObject private var webServer = LocalWebServer.shared
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isSignedIn {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(auth)
                        .environmentObject(webServer)
                        .overlay(alignment: .top) {
                            if webServer.showTokenPopup {
                                TokenPopupView()
                                    .environmentObject(webServer)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .zIndex(999)
                            }
                        }
                        .animation(.spring(), value: webServer.showTokenPopup)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
            .preferredColorScheme(preferredColorScheme)
        }
    }
}
