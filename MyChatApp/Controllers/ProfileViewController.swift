//
//  ProfileViewController.swift
//  MyChatApp
//
//  Created by Андрей on 29.10.2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

/// Controller that shows user profile info
final class ProfileViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logOut, title: "LogOut", handler: { [weak self] in
            guard let strongSelf = self else { return }
            
            UserDefaults.standard.set(nil, forKey: "name")
            UserDefaults.standard.set(nil, forKey: "email")
            
            let actionSheet = UIAlertController(title: "Do you want to Log Out?",
                                          message: "",
                                          preferredStyle: .actionSheet)
            
            actionSheet.addAction(UIAlertAction(title: "Log Out",
                                                style: .destructive,
                                                handler: { _ in
                
               
                
                // Log Out Facebook
                FBSDKLoginKit.LoginManager().logOut()
                
                // Log Out Google
                GIDSignIn.sharedInstance.signOut()
                
                // Log Out Firebase
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)
                }
                catch {
                    print("Failed to log out")
                }
            }))
            
            actionSheet.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel))
            
            strongSelf.present(actionSheet, animated: true)
        }))
        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let fileName = safeEmail + "_profile_picture.png"
        
        let path = "images/\(fileName)"
        let headerView = UIView(frame: CGRect(x: 0,
                                              y: 0,
                                              width: view.width,
                                              height: 300))
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2,
                                                  y: 75,
                                                  width: 150,
                                                  height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.layer.borderWidth = 3
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
                
            case .success(let url):
                imageView.sd_setImage(with: url)
            case .failure(let error):
                print("Failed to get url: \(error)")
            }
        }
        
        return headerView
    }
}

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        
        let viewModel = data[indexPath.row]
        cell.setUp(cell, with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
       data[indexPath.row].handler?()
    }
}

class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"
    
    public func setUp(_ cell: ProfileTableViewCell, with viewModel: ProfileViewModel) {
        var content = cell.defaultContentConfiguration()
        content.text = viewModel.title
        switch viewModel.viewModelType {
            
        case .info:
            content.textProperties.alignment = .natural
            cell.selectionStyle = .none
        case .logOut:
            content.textProperties.alignment = .center
            content.textProperties.color = .red
           
        }
        cell.contentConfiguration = content
    }
}
