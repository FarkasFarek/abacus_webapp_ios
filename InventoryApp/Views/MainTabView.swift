import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Áttekintés", systemImage: "house.fill") }.tag(0)
            ScannerView()
                .tabItem { Label("Beolvasás", systemImage: "qrcode.viewfinder") }.tag(1)
            ProductListView()
                .tabItem { Label("Termékek", systemImage: "shippingbox.fill") }.tag(2)
            TransactionListView()
                .tabItem { Label("Mozgások", systemImage: "arrow.left.arrow.right.circle.fill") }.tag(3)
            ReportsView()
                .tabItem { Label("Riportok", systemImage: "chart.bar.fill") }.tag(4)
            SettingsView()
                .tabItem { Label("Beállítások", systemImage: "gearshape.fill") }.tag(5)
        }
        .accentColor(.blue)
    }
}
