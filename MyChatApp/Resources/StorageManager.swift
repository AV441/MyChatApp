//
//  StorageManager.swift
//  MyChatApp
//
//  Created by Андрей on 31.10.2022.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch and load files to Firebase Storage
final class StorageManager {
    
    /// Shared incstance of class
    static let shared = StorageManager()
    
    private init() {}
    
    private let metadata = StorageMetadata()
    
    private var storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    /// Uploads picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        let reference = storage.child("images/\(fileName)")
        reference.putData(data, metadata: nil) { metadata, error in
            guard error == nil else {
                print("Failed to upload a picture to firebase storage")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            reference.downloadURL { url, error in
                guard let url = url else {
                    print("Failed to download url")
                    completion(.failure(StorageErrors.failedToDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    /// Uploads image that will be send in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        let reference = storage.child("message_images/\(fileName)")
        reference.putData(data, metadata: nil) { metadata, error in
            
            guard error == nil else {
                print("Failed to upload a picture to firebase storage")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            reference.downloadURL { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(StorageErrors.failedToDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url: \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    /// Uploads video that will be send in a conversation message
    public func uploadMessageVideo(with fileURL: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        metadata.contentType = "video/quicktime"
        
        if let videoData = NSData(contentsOf: fileURL) as Data? {
            storage.child("message_videos/\(fileName)").putData(videoData, metadata: metadata) { [weak self] metadata, error in
                guard error == nil else {
                    print("Failed to upload a video file to firebase storage")
                    completion(.failure(StorageErrors.failedToUpload))
                    return
                }
                
                self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
                    guard let url = url else {
                        print("Failed to get download url")
                        completion(.failure(StorageErrors.failedToDownloadUrl))
                        return
                    }
                    
                    let urlString = url.absoluteString
                    print("download url: \(urlString)")
                    completion(.success(urlString))
                }
            }
        }
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToDownloadUrl
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL { url, error in
            guard let url = url,
                  error == nil else {
                completion(.failure(StorageErrors.failedToDownloadUrl))
                return
            }
            
            completion(.success(url))
        }
    }
}
