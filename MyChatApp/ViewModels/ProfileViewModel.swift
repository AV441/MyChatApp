//
//  ProfileViewModel.swift
//  MyChatApp
//
//  Created by Андрей on 07.11.2022.
//

import Foundation

enum ProfileViewModelType {
    case info, logOut
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
