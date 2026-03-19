import SwiftUI

struct TokenPopupView: View {
    @EnvironmentObject var webServer: LocalWebServer
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Web szerver aktív")
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        withAnimation { webServer.showTokenPopup = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }

                Divider()

                VStack(spacing: 6) {
                    Text("Nyisd meg böngészőben:")
                        .font(.caption).foregroundColor(.secondary)
                    Text(webServer.serverURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                }

                VStack(spacing: 6) {
                    Text("Belépési token:").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Text(webServer.accessToken)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .tracking(8)
                            .foregroundColor(.primary)
                        Button {
                            UIPasteboard.general.string = webServer.accessToken
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundColor(copied ? .green : .blue)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                Text("A token 30 percenként automatikusan változik")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(16)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}
