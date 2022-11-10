//
//  ChatViewController.swift
//  MyChatApp
//
//  Created by Андрей on 31.10.2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

/// Controller that shows collection of messages in chosen conversation
final class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        formatter.dateFormat = "dd_MM_yyyy_HH_mm"
        return formatter
    }()
    
    private var senderPhotoURL: URL?

    private var recipientPhotoURL: URL?
    
    public var isNewConversation = false
    
    public let otherUserEmail: String
    
    public var conversationID: String?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        return Sender(senderId: safeEmail,
                      displayName: "Me")
    }
    
    init(with email: String, id: String?) {
        self.conversationID = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGreen
        setDelagates()
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let conversationID = conversationID {
            listenForMessages(id: conversationID)
        }
    }
    
    private func setDelagates() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35,
                              height: 35),
                       animated: false)
        button.setImage(UIImage(systemName: "paperclip"),
                        for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo",
                                            style: .default) { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Video",
                                            style: .default) { [weak self] _ in
            self?.presentVideoInputActionSheet()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Audio",
                                            style: .default) { [weak self] _ in
            
        })
        
        actionSheet.addAction(UIAlertAction(title: "Location",
                                            style: .default) { [weak self] _ in
            self?.presentLocationPicker()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil, isPickable: true)
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            guard let strongSelf = self else { return }
            
            guard
                let messageID = strongSelf.createMessageID(),
                let conversationID = strongSelf.conversationID,
                let name = strongSelf.title,
                let sender = strongSelf.selfSender
            else {
                return
            }
            
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            let location = Location(location: CLLocation(latitude: latitude,
                                                          longitude: longitude),
                                     size: .zero)
            
            let message = Message(sender: sender,
                                  messageId: messageID,
                                  sentDate: .now,
                                  kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                if success {
                    print("Sent location message")
                } else {
                    print("Failed to sent location message")
                }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "How would you like to attach photo?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Library",
                                            style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Vidoe",
                                            message: "How would you like to attach video?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Library",
                                            style: .default) { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func listenForMessages(id: String) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id) { [weak self] result in
            switch result {
                
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadData()
                    self?.messagesCollectionView.scrollToLastItem()
                }
                
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard
            let messageID = createMessageID(),
            let conversationID = conversationID,
            let name = title,
            let sender = selfSender
        else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // Upload image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else { return }
                
                switch result {
                    
                case .success(let urlString):
                    // ready to send message
                    print("Uploaded message photo: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "photo.artframe") else {
                        return
                    }
                    
                    let mediaItem = Media(url: url,
                                          image: nil,
                                          placeholderImage: placeholder,
                                          size: .zero)
                    
                    let message = Message(sender: sender,
                                          messageId: messageID,
                                          sentDate: .now,
                                          kind: .photo(mediaItem))
                    
                    DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                        if success {
                            print("Sent photo message")
                        } else {
                            print("Failed to sent photo message")
                        }
                    }
                case .failure(let error):
                    print("Failed to upload message photo: \(error)")
                }
            }
        } else if let videoURL = info[.mediaURL] as? URL {
            let fileName = "video_message_" + messageID.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            // Upload Video
            
            StorageManager.shared.uploadMessageVideo(with: videoURL, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else { return }
                
                switch result {
                    
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded message video: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "photo.artframe") else {
                        return
                    }
                    
                    let mediaItem = Media(url: url,
                                          image: nil,
                                          placeholderImage: placeholder,
                                          size: .zero)
                    
                    let message = Message(sender: sender,
                                          messageId: messageID,
                                          sentDate: .now,
                                          kind: .video(mediaItem))
                    
                    DatabaseManager.shared.sendMessage(to: conversationID, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                        if success {
                            print("Sent video message")
                        } else {
                            print("Failed to sent video message")
                        }
                    }
                case .failure(let error):
                    print("Failed to upload message video: \(error)")
                }
            }
        }
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        } else {
            fatalError("selfSender is nil, email should be cached")
        }
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageURL = media.url else {
                return
            }
            
            imageView.sd_setImage(with: imageURL)
            
        case .video(let media):
            guard let videoURL = media.url else {
                return
            }
            
            DatabaseManager.shared.getThumbnailImageFromVideoUrl(url: videoURL) { result in
                switch result {
                    
                case .success(let thumbNailImage):
                    guard let image = thumbNailImage else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                    
                case .failure(let error):
                    print("Failed to fetch thumbNailImage: \(error)")
                }
            }
        default:
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // our message
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // show our image
            if let currentUserURL = senderPhotoURL {
                avatarView.sd_setImage(with: currentUserURL)
            } else {
                // fetch URL
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                
                let safeEmail = DatabaseManager.safeEmail(email: email)
                
                StorageManager.shared.downloadURL(for: "images/\(safeEmail)_profile_picture.png") { [weak self] result in
                    switch result {
                        
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        } else {
            // show recipient image
            if let otherUserURL = recipientPhotoURL {
                avatarView.sd_setImage(with: otherUserURL)
            } else {
                // fetch URL
                let email = otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(email: email)
                StorageManager.shared.downloadURL(for: "images/\(safeEmail)_profile_picture.png") { [weak self] result in
                    switch result {
                        
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates, isPickable: false)
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageURL = media.url else {
                return
            }
            
            let vc = PhotoViewController(with: imageURL)
            navigationController?.pushViewController(vc, animated: true)
            
        case .video(let media):
            guard let videoURL = media.url else {
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoURL)
            vc.player?.play()
            present(vc, animated: true)
            
        default:
            break
        }
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let sender = selfSender,
              let messageID = createMessageID() else {
            return
        }
        
        let message = Message(sender: sender,
                              messageId: messageID,
                              sentDate: .now,
                              kind: .text(text))
        
        DispatchQueue.main.async { [weak self] in
            self?.messageInputBar.inputTextView.text = nil
        }
        
        // Send message
        if isNewConversation {
            // create conversation in databse
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                         name: title ?? "user",
                                                         firstMessage: message) { [weak self] success in
                
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationID = "conversation_\(message.messageId)"
                    self?.conversationID = newConversationID
                    self?.listenForMessages(id: newConversationID)
                } else {
                    print("failed to sent")
                }
            }
        } else {
            // append to existing conversation data
            guard
                let conversationID = conversationID,
                let name = title
            else {
                return
            }
            
            DatabaseManager.shared.sendMessage(to: conversationID,
                                               otherUserEmail: otherUserEmail,
                                               name: name,
                                               newMessage: message) { success in
               
                if success {
                    print("message sent")
                } else {
                    print("failed to sent")
                }
            }
        }
    }
    
    private func createMessageID() -> String? {
        // date, otherUserEmail, senderEmail
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let dateString = ChatViewController.dateFormatter.string(from: Date())
        
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        
        return newIdentifier
    }
}
