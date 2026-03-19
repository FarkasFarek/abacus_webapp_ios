import Foundation
import AuthenticationServices
import SwiftUI

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var isSignedIn: Bool = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var userEmail: String = ""

    private let userIDKey = "appleUserID"
    private let userNameKey = "appleUserName"
    private let userEmailKey = "appleUserEmail"

    override init() {
        super.init()
        loadSavedCredentials()
    }

    private func loadSavedCredentials() {
        if let savedID = UserDefaults.standard.string(forKey: userIDKey), !savedID.isEmpty {
            userID = savedID
            userName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
            userEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
            // Ellenőrizzük a credential érvényességét
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: savedID) { state, _ in
                DispatchQueue.main.async {
                    self.isSignedIn = (state == .authorized)
                    if !self.isSignedIn { self.clearCredentials() }
                }
            }
        }
    }

    func signIn(credential: ASAuthorizationAppleIDCredential) {
        let id = credential.user
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        let email = credential.email ?? ""

        userID = id
        if !name.isEmpty { userName = name }
        if !email.isEmpty { userEmail = email }
        isSignedIn = true

        UserDefaults.standard.set(id, forKey: userIDKey)
        if !name.isEmpty { UserDefaults.standard.set(name, forKey: userNameKey) }
        if !email.isEmpty { UserDefaults.standard.set(email, forKey: userEmailKey) }
        UserDefaults.standard.set(userName.isEmpty ? "Felhasználó" : userName, forKey: "currentUser")
    }

    func signOut() {
        clearCredentials()
    }
    
    func signInAsGuest() {
        userID = "guest"
        userName = "Vendég"
        isSignedIn = true
        UserDefaults.standard.set("guest", forKey: "appleUserID")
        UserDefaults.standard.set("Vendég", forKey: "appleUserName")
        UserDefaults.standard.set("Vendég", forKey: "currentUser")
    }

    private func clearCredentials() {
        isSignedIn = false
        userID = ""
        userName = ""
        userEmail = ""
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
    }
}

// Apple Sign In Button
struct AppleSignInButton: UIViewRepresentable {
    var onSuccess: (ASAuthorizationAppleIDCredential) -> Void
    var onError: (Error) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: AppleSignInButton
        init(parent: AppleSignInButton) { self.parent = parent }

        @objc func tapped() {
            let req = ASAuthorizationAppleIDProvider().createRequest()
            req.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [req])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController,
                                     didCompleteWithAuthorization authorization: ASAuthorization) {
            if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
                parent.onSuccess(cred)
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onError(error)
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
