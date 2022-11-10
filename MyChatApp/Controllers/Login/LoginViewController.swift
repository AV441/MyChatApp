//
//  LoginViewController.swift
//  MyChatApp
//
//  Created by Андрей on 28.10.2022.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD

final class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let googleLoginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Continue with Google", for: .normal)
        button.setImage(UIImage(named: "Google logo"),
                        for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        
        button.setTitleColor(UIColor.black, for: .normal)
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 12
        return button
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        
        title = "Log In"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sign Up",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegister))
        
        loginButton.addTarget(self,
                              action: #selector(loginButtonTapped),
                              for: .touchUpInside)
        
        googleLoginButton.addTarget(self,
                                    action: #selector(googleLoginButtonTapped),
                                    for: .touchUpInside)
        
        //Delegates
        emailField.delegate = self
        passwordField.delegate = self
        facebookLoginButton.delegate = self
        
        //Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        scrollView.addSubview(googleLoginButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width - size)/2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom + 10,
                                   width: scrollView.width - 60,
                                   height: 52)
        
        facebookLoginButton.frame = CGRect(x: 30,
                                           y: loginButton.bottom + 10,
                                           width: scrollView.width - 60,
                                           height: 52)
        
        googleLoginButton.frame = CGRect(x: 30,
                                         y: facebookLoginButton.bottom + 10,
                                         width: scrollView.width - 60,
                                         height: 52)
    }
    
    @objc private func didTapRegister() {
        let vc = RegistrationViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func loginButtonTapped() {
        
        view.endEditing(true)
        
        guard let email = emailField.text,
              let password = passwordField.text,
              !email.isEmpty,
              password.count >= 6
        else {
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        // Log In with email and password
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let strongSelf = self else { return }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            guard
                authResult != nil,
                error == nil
            else {
                print("Failed to Sign In with email and password")
                return
            }
            
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            DatabaseManager.shared.getDataFor(path: safeEmail) { result in
                
                switch result {
                    
                case .success(let data):
                    guard
                        let userData = data as? [String: Any],
                        let firstName = userData["first_name"] as? String,
                        let lastName = userData["last_name"] as? String
                    else {
                        return
                    }
                    
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                    
                case .failure(let error):
                    print("Failed to read data: \(error)")
                }
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            
            strongSelf.dismiss(animated: true)
        }
    }
    
    private func alertUserLoginError() {
        let alert = UIAlertController(title: "Error",
                                      message: "Please enter all information to Log In",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss",
                                      style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func googleLoginButtonTapped() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(with: config, presenting: self) { user, error in
            
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
            else {
                print("Missing auth object off of google user")
                return
            }
            
            // Create credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            
            FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let strongSelf = self else { return }
                
                guard
                    authResult != nil,
                    error == nil
                else {
                    print("Google credential login failed: \(String(describing: error))")
                    return
                }
                
                // If auth is sucsess, get user data
                guard
                    let email = user?.profile?.email,
                    let firstName = user?.profile?.givenName,
                    let lastName = user?.profile?.familyName
                else {
                    return
                }
                
                UserDefaults.standard.set(email, forKey: "email")
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                
                // Check if users is already exists
                DatabaseManager.shared.isUserExists(with: email) { exists in
                    if !exists {
                        
                        let chatUser = ChatAppUser(firstName: firstName,
                                                   lastName: lastName,
                                                   emailAddress: email)
                        
                        DatabaseManager.shared.insertUser(with: chatUser) { success in
                            if success {
                                //upload image
                                
                                guard
                                    user?.profile?.hasImage != nil,
                                    let url = user?.profile?.imageURL(withDimension: 200) else {
                                    return
                                }
                                
                                URLSession.shared.dataTask(with: url) { data, response, error in
                                    guard let data = data else {
                                        print("failed to get data from google")
                                        return
                                    }
                                    
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                        switch result {
                                            
                                        case .success(let downloadUrl):
                                            UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                            print(downloadUrl)
                                        case .failure(let error):
                                            print(error)
                                        }
                                    }
                                }.resume()
                            }
                        }
                    } else {
                        print("user for this email is already exists")
                    }
                }
                
                strongSelf.dismiss(animated: true)
            }
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    
    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
        }
        else if textField == passwordField {
            loginButtonTapped()
        }
        
        return true
    }
}

extension LoginViewController: LoginButtonDelegate {
    
    internal func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // no operations
    }
    
    // Log In with Facebook
    internal func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("User failed to log in with facebook")
            return
        }
        
        // create credential
        let credential = FacebookAuthProvider.credential(withAccessToken: token)
        
        FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let strongSelf = self else { return }
            
            guard authResult != nil,
                  error == nil
            else {
                print("!!!Facebook credential login failed: \(String(describing: error))")
                return
            }
            
            // If auth is sucsess, request user data to add to Database
            let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                             parameters: ["fields": "email, first_name, last_name, picture.type(large)"],
                                                             tokenString: token,
                                                             version: nil,
                                                             httpMethod: .get)
            facebookRequest.start { _, result, error in
                guard let result = result as? [String: Any],
                      error == nil
                else {
                    print("Failed to make facebook graph request")
                    return
                }
                
                guard
                    let firstName = result["first_name"] as? String,
                    let lastName = result["last_name"] as? String,
                    let email = result["email"] as? String,
                    let picture = result["picture"] as? [String: Any],
                    let data = picture["data"] as? [String: Any],
                    let pictureUrl = data["url"] as? String
                else {
                    print("Failed to get name and email from facebook")
                    return
                }
                
                UserDefaults.standard.set(email, forKey: "email")
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                
                // Check if the user already exists
                DatabaseManager.shared.isUserExists(with: email) { exists in
                    if !exists {
                        let chatUser = ChatAppUser(firstName: firstName,
                                                   lastName: lastName,
                                                   emailAddress: email)
                        
                        DatabaseManager.shared.insertUser(with: chatUser) { success in
                            if success {
                                
                                guard let url = URL(string: pictureUrl) else {
                                    return
                                }
                                
                                URLSession.shared.dataTask(with: url) { data, _, error in
                                    guard let data = data else {
                                        print("Failed to get data from facebook")
                                        return
                                    }
                                    //upload image
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName) { result in
                                        switch result {
                                            
                                        case .success(let downloadUrl):
                                            UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                            print(downloadUrl)
                                        case .failure(let error):
                                            print(error)
                                        }
                                    }
                                }.resume()
                            }
                        }
                    } else {
                        print("User for this email is already exists")
                        return
                    }
                }
            }
            
            strongSelf.dismiss(animated: true)
        }
    }
}
