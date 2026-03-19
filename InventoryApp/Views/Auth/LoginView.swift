import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.2, green: 0.0, blue: 0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                    Text("Készletnyilvántartó")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("Professzionális leltárkezelés")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "icloud.fill",      text: "iCloud szinkronizáció")
                    featureRow(icon: "person.2.fill",    text: "Több felhasználó / eszköz")
                    featureRow(icon: "lock.shield.fill", text: "Apple biztonság")
                }
                .padding(.horizontal, 40)

                VStack(spacing: 14) {
                    AppleSignInButton(
                        onSuccess: { credential in auth.signIn(credential: credential) },
                        onError:   { error in errorMessage = error.localizedDescription }
                    )
                    .frame(height: 54)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    Button {
                        auth.signInAsGuest()
                    } label: {
                        Text("Folytatás belépés nélkül")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage).font(.caption).foregroundColor(.red)
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.9))
    }
}
