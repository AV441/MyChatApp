//
//  DatabaseManager.swift
//  MyChatApp
//
//  Created by Андрей on 28.10.2022.
//

import Foundation
import FirebaseDatabase
import MessageKit
import AVFoundation
import CoreLocation


/// Manager object to read and write data to Firebase Realtime Database
final class DatabaseManager {
    
    /// Shared incstance of class
    public static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    private init() {}
    
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}
extension DatabaseManager {
    
    /// Returns dictionary node at child path
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observe(.value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}

//MARK: Account Management
extension DatabaseManager {
    
    /// Checks if user account for given email is already exists
    /// - `email`:              Target email to be checked
    /// - `completion`:   Async closure to return with result
    public func isUserExists(with email: String,
                             completion: @escaping ((Bool) -> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard
                snapshot.value as? [String: Any] != nil
            else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            guard let strongSelf = self else { return }
            
            guard error == nil else {
                print("Failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                } else {
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    strongSelf.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                }
            }
            
            completion(true)
        })
    }
    
    /// Gets all users from Database
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
    }
    
    /// Fetches thumbNail image for video
    public func getThumbnailImageFromVideoUrl(url: URL, completion: @escaping (Result<UIImage?, Error>) -> Void) {
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let avAssetImageGenerator = AVAssetImageGenerator(asset: asset)
            avAssetImageGenerator.appliesPreferredTrackTransform = true
            let thumbNailTime = CMTimeMake(value: 1, timescale: 60)
            do {
                let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: thumbNailTime, actualTime: nil)
                let thumbNailImage = UIImage(cgImage: cgThumbImage)
                completion(.success(thumbNailImage))
            } catch {
                completion(.failure(DatabaseErrors.failedToFetch))
            }
        }
    }
    
    public enum DatabaseErrors: Error {
        case failedToFetch
        
        public var localizedDescription: String {
            switch self {
                
            case .failedToFetch:
                return "Cant fetch data from Database. Check your internet connection."
            }
        }
    }
}

// MARK: Sending messages / conversations
extension DatabaseManager {
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard
            let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
            let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: currentEmail)
        let reference = database.child("\(safeEmail)")
        
        reference.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            // Update recipient conversation entry
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            }
            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array is exists for the current user
                // you should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                
                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            } else {
                // conversation array do not exists
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                reference.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name: name,
                                                     conversationID: conversationID,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                }
            }
        }
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        
        switch firstMessage.kind {
            
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(email: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        print("adding conversation: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap { dictionary in
                
                guard
                    let conversationID = dictionary["id"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool
                else {
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                return Conversation(id: conversationID,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { dictionary in
                
                guard
                    let name = dictionary["name"] as? String,
                    let isRead = dictionary["is_read"] as? Bool,
                    let messageID = dictionary["id"] as? String,
                    let content = dictionary["content"] as? String,
                    let senderEmail = dictionary["sender_email"] as? String,
                    let type = dictionary["type"] as? String,
                    let dateString = dictionary["date"] as? String,
                    let date = ChatViewController.dateFormatter.date(from: dateString)
                else {
                    return nil
                }
                
                var kind: MessageKind?
                if type == "photo" {
                    // photo
                    guard
                        let imageURL = URL(string: content),
                        let placeholder = UIImage(systemName: "photo.artframe")
                    else {
                        return nil
                    }
                    
                    let media = Media(url: imageURL,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300,
                                                   height: 300))
                    kind = .photo(media)
                }
                else if type == "video" {
                    // video
                    guard
                        let videoURL = URL(string: content),
                        let placeholder = UIImage(systemName: "film.fill")
                    else {
                        return nil
                    }
                    
                    let media = Media(url: videoURL,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300,
                                                   height: 300))
                    kind = .video(media)
                }
                else if type == "location" {
                    // location
                    
                    let locationComponents = content.components(separatedBy: ",")
                    guard
                        let longitude = Double(locationComponents[0]),
                        let latitude = Double(locationComponents[1])
                    else {
                        return nil
                    }

                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                            size: CGSize(width: 300, height: 300))

                    kind = .location(location)

                }
                else {
                    kind = .text(content)
                }
                
                guard let kind = kind else {
                    return nil
                }
                
                let sender = Sender(senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: kind)
            }
            completion(.success(messages))
        }
    }
    
    /// Sends a message to target conversation
    public func sendMessage(to conversationID: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let otherUserSafeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        
        database.child("\(conversationID)/messages").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let strongSelf = self else { return }
            
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserSafeEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversationID)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                // Update latest message for the sender
                strongSelf.database.child("\(currentUserSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "message": message,
                        "is_read": false
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        
                        var targetConversation: [String: Any]?
                        var position = 0
                        
                        for conversation in currentUserConversations {
                            if let currentID = conversation["id"] as? String, currentID == conversationID {
                                targetConversation = conversation
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversationID,
                                "other_user_email": otherUserSafeEmail,
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversationID,
                            "other_user_email": otherUserSafeEmail,
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [newConversationData]
                    }
                    
                    strongSelf.database.child("\(currentUserSafeEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                    }
                
                // Update latest message for the recipient user
                strongSelf.database.child("\(otherUserSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "message": message,
                        "is_read": false
                    ]
                    
                    guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                        return
                    }
                    
                    if var otherUserConversations = snapshot.value as? [[String: Any]] {
                        
                        var targetConversation: [String: Any]?
                        var position = 0
                        
                        for conversation in otherUserConversations {
                            if let currentID = conversation["id"] as? String,
                               currentID == conversationID {
                                targetConversation = conversation
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation = targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            otherUserConversations[position] = targetConversation
                            databaseEntryConversations = otherUserConversations
                        } else {
                            // Failed to find in current collection
                            let newConversationData: [String: Any] = [
                                "id": conversationID,
                                "other_user_email": currentUserSafeEmail,
                                "name": currentName,
                                "latest_message": updatedValue
                            ]
                            otherUserConversations.append(newConversationData)
                            databaseEntryConversations = otherUserConversations
                        }
                    } else {
                        // current collection does not exists
                        let newConversationData: [String: Any] = [
                            "id": conversationID,
                            "other_user_email": currentUserSafeEmail,
                            "name": currentName,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [newConversationData]
                    }
                    
                    strongSelf.database.child("\(otherUserSafeEmail)/conversations").setValue(databaseEntryConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
        }
    }
}
    
    public func deleteConversation(conversationID: String, completion: @escaping (Bool) -> Void ) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        print("Deleting conversation with ID: \(conversationID)")
        
        // Get all conversations for the current user
        // Delete conversation with target ID
        // Reset conversations for the current user in database
        let reference = database.child("\(safeEmail)/conversations")
        reference.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String,
                    id == conversationID {
                        print("Found conversation to delete")
                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                reference.setValue(conversations) { error, _ in
                    guard error == nil else {
                        completion(false)
                        print("Failed to write new Conversation array")
                        return
                    }
                    print("Conversation has been deleted")
                    completion(true)
                }
            }
        }
    }
    
    public func isConversationExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
       
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeSenderEmail = DatabaseManager.safeEmail(email: senderEmail)
        let safeRecipientEmail = DatabaseManager.safeEmail(email: targetRecipientEmail)
        
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            
            // iterate and find conversation with targer sender
            if let targetConversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // get ID
                guard let id = targetConversation["id"] as? String else {
                    completion(.failure(DatabaseErrors.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseErrors.failedToFetch))
            return
        }
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
