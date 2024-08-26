//
//  ViewController.swift
//  SignInTrial
//
//  Created by Harikrishnan V S (MA-IN) on 27/05/24.
//
import AuthenticationServices
import UIKit
import CryptoKit
import Firebase
import FirebaseAuth
import GoogleSignIn
@available(iOS 13.0, *)
class ViewController: UIViewController {
    private let appleSignInBtn = ASAuthorizationAppleIDButton()
    private let googleSignInBtn = GIDSignInButton()
    fileprivate var currentNonce: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.addSubview(appleSignInBtn)
        view.addSubview(googleSignInBtn)
        appleSignInBtn.addTarget(self, action: #selector(didTapAppleSignIn), for: .touchUpInside)
        googleSignInBtn.addTarget(self, action: #selector(didTapGoogleSignIn), for: .touchUpInside)
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        appleSignInBtn.frame = CGRect(x: 0, y: 0, width: 250, height: 50)
        appleSignInBtn.center = CGPoint(x: view.center.x , y: view.center.y + 30)
        googleSignInBtn.frame = CGRect(x: 0, y: 0, width: 250, height: 50)
        googleSignInBtn.center = CGPoint(x: view.center.x , y: view.center.y - 30)
    }
    
    @objc func didTapAppleSignIn(){
        
        let nonce = Utilities.randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Utilities.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
    }
    @objc func didTapGoogleSignIn(){
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] authentication , error in
            if let error = error{
                print("failed! : \(error.localizedDescription)")
                return
            }
            
            guard let user = authentication?.user, let idToken = user.idToken else{
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { result, error in
                
                DispatchQueue.main.asyncAfter(deadline: .now()+1){
                    self.navigate(to: "GoogleVC")
                }
            }
        }
    }
}



@available(iOS 13.0, *)
extension ViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding{
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                print("Invalid state: A login callback was received, but no login request was sent.")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
            return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return
            }
            print(appleIDCredential.fullName ?? "No name")
            print(appleIDCredential.email ?? "No email")
            // Initialize a Firebase credential, including the user's full name.
//            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,rawNonce: nonce,fullName: appleIDCredential.fullName)
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { (authResult, error) in
            if let err = error {
                print(err.localizedDescription)
                return
            }
                print(Auth.auth().currentUser?.uid)
            // User is signed in to Firebase with Apple.
            // ...
                DispatchQueue.main.asyncAfter(deadline: .now()+1){
                    self.navigate(to: "AppleVC")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        print("failed!")
    }
}

@available(iOS 13.0, *)
extension ViewController{
    func navigate(to page:String){
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DetailsVC") as! DetailsVC
        vc.provider = page
        present(vc, animated: true)
    }
}
class Utilities{
    
    static func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      var randomBytes = [UInt8](repeating: 0, count: length)
      let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
      if errorCode != errSecSuccess {
        fatalError(
          "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
        )
      }

      let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

      let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
      }

      return String(nonce)
    }

    @available(iOS 13, *)
    static func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()

      return hashString
    }

}

class DetailsVC:UIViewController{
    @IBOutlet weak var logoImg: UIImageView!
    @IBOutlet weak var welcomeLabel: UILabel!
    var provider:String = ""
    @IBAction func logout(_ sender: Any) {
        let firebaseAuth = Auth.auth()
        do {
          try firebaseAuth.signOut()
        } catch let signOutError as NSError {
          print("Error signing out: %@", signOutError)
        }
        self.dismiss(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.async{ [weak self] in
            self?.welcomeLabel.text = "Welcome \(Auth.auth().currentUser?.providerData[0].email ?? Auth.auth().currentUser?.providerData[0].displayName ?? "Unknown")"
            switch self?.provider{
            case "AppleVC":
                if #available(iOS 13.0, *) {
                    self?.logoImg.image = UIImage(systemName: "apple.logo")
                } else {
                    self?.logoImg.image = UIImage(named: "apple.logo")
                }
            case "GoogleVC":
                self?.logoImg.image = UIImage(named: "google")
            default:
                return
            }
        }
    }
    
}
