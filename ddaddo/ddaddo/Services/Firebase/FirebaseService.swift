//
//  FirebaseService.swift
//  ddaddo
//
//  Created by sun on 10/29/26.
//

import FirebaseCore
import Foundation

enum FirebaseService {
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return
        }

        FirebaseApp.configure()
    }
}
