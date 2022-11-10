//
//  NewConversationViewController.swift
//  MyChatApp
//
//  Created by Андрей on 28.10.2022.
//

import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> Void)?
    
    private var users = [[String: String]]()
    
    private var results = [SearchResult]()
    
    private var hasFetched = false
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationTableViewCell.self, forCellReuseIdentifier: NewConversationTableViewCell.identifier)
        return tableView
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Results"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.textColor = .gray
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(noResultsLabel)
        
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        
        noResultsLabel.frame = CGRect(x: view.center.x - (view.width / 4),
                                      y: (view.height - 200) / 2,
                                      width: view.width / 2,
                                      height: 200)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

extension NewConversationViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard
            let text = searchBar.text,
            !text.replacingOccurrences(of: " ", with: "").isEmpty
        else {
            return
        }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        
        spinner.show(in: view)
        
        searchUsers(query: text)
    }
    
    private func searchUsers(query: String) {
        // check if array has firebase results
        if hasFetched {
            // if it does: filter
            filterUsers(with: query)
        } else {
            // if not, fetch then filter
            DatabaseManager.shared.getAllUsers { [weak self] result in
                guard let strongSelf = self else { return }
                
                switch result {
                    
                case .success(let usersCollection):
                    strongSelf.hasFetched = true
                    strongSelf.users = usersCollection
                    strongSelf.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to get users: \(error)")
                }
            }
        }
    }
    
    private func filterUsers(with term: String) {
        // update UI: either show results or show noResultsLabel
        guard
            let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
            hasFetched
        else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        spinner.dismiss()
        
        let results: [SearchResult] = users.filter({
            guard let email = $0["email"],
                  email != safeEmail else {
                return false
            }
            
            guard let name = $0["name"]?.lowercased() else {
                return false
            }
            
            return name.hasPrefix(term.lowercased())
        }).compactMap({
            guard
                let email = $0["email"],
                let name = $0["name"]
            else {
                return nil
            }
            return SearchResult(name: name, email: email)
        })
        
        self.results = results

        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        } else {
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
    
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationTableViewCell.identifier,
                                                 for: indexPath) as! NewConversationTableViewCell
        let model = results[indexPath.row]
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        // start conversation
        let targetUserData = results[indexPath.row]
        
        dismiss(animated: true) { [weak self] in
            self?.completion?(targetUserData)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
