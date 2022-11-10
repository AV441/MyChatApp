//
//  ViewController.swift
//  MyChatApp
//
//  Created by Андрей on 28.10.2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {
    
    private var conversations = [Conversation]()
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(ConversationTableViewCell.self,
                           forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return tableView
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.textColor = .gray
        label.isHidden = true
        return label
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTapComposeButton))
        
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.startListeningForConversations()
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        
        noConversationsLabel.frame = CGRect(x: 10,
                                            y: (view.height - 100) / 2,
                                            width: view.width - 20,
                                            height: 100)
    }
    
    private func startListeningForConversations() {
        if let loginObserver = loginObserver {
            NotificationCenter.default.removeObserver(loginObserver)
        }
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        DatabaseManager.shared.getAllConversations(for: safeEmail) { [weak self] result in
            
            switch result {
            case .success(let conversations):
                guard !conversations.isEmpty else {
                    self?.tableView.isHidden = true
                    self?.noConversationsLabel.isHidden = false
                    print("Conversations is empty")
                    return
                }
                
                self?.tableView.isHidden = false
                self?.noConversationsLabel.isHidden = true
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationsLabel.isHidden = false
                print("Failed to get conversations: \(error)")
            }
        }
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            
            let currentConversations = strongSelf.conversations
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(email: result.email)
            }) {
                let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
                
            } else {
                strongSelf.createNewConversation(result: result)
            }
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    private func createNewConversation(result: SearchResult) {
        let name = result.name
        let email = DatabaseManager.safeEmail(email: result.email)
        
        // check if conversation with two users exists in database
        // if it does, reuse conversation ID
        // otherwise use existing code
        
        DatabaseManager.shared.isConversationExists(with: email) { [weak self] result in
            guard let strongSelf = self else { return }
            
            switch result {
                
            case .success(let conversationID):
                // this is an existing conversation
                let vc = ChatViewController(with: email, id: conversationID)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                // this is a new conversation
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func fetchConversations() {
        tableView.isHidden = false
    }
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,
                                                 for: indexPath) as! ConversationTableViewCell
        
        let model = conversations[indexPath.row]
        
        cell.configure(with: model)
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = conversations[indexPath.row]
        openConversation(with: model)
    }
    
    private func openConversation(with model: Conversation) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    internal func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    internal func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            // Begin delete
            let conversationID = conversations[indexPath.row].id
            tableView.beginUpdates()
            
            // Update UI
            conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Update Model
            DatabaseManager.shared.deleteConversation(conversationID: conversationID) { success in
                if !success {
                    // TODO: Add row back and show error allert
                }
            }
            tableView.endUpdates()
        }
    }
}
