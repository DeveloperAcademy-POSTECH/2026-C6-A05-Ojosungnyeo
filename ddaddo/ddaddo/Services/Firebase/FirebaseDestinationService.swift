//
//  FirebaseDestinationService.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import FirebaseFirestore

enum FirebaseDestinationService {
    static func fetchDestinations() async throws -> [TripDestination] {
        guard FirebaseService.isConfigured else {
            throw DestinationServiceError.firebaseNotConfigured
        }

        let database = Firestore.firestore()
        let destinationCollection = database.collection("destinations")
        let snapshot = try await destinationCollection.getDocuments()

        let destinations: [TripDestination] = try snapshot.documents.compactMap { document -> TripDestination? in
            let data = document.data()
            guard (data["isActive"] as? Bool) ?? true else { return nil }
            guard
                let country = data["country"] as? String,
                let name = data["name"] as? String,
                let regionValue = data["region"] as? String,
                let region = TripDestination.Region(serverValue: regionValue),
                let thumbnailName = data["thumbnailName"] as? String
            else {
                throw DestinationServiceError.invalidDocument(document.documentID)
            }

            return TripDestination(
                id: document.documentID,
                country: country,
                name: name,
                region: region,
                thumbnailName: thumbnailName,
                sortOrder: data["sortOrder"] as? Int ?? .max
            )
        }
        .sorted { (lhs: TripDestination, rhs: TripDestination) in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        guard !destinations.isEmpty else {
            throw DestinationServiceError.emptyCatalog
        }
        return destinations
    }

}

enum DestinationServiceError: LocalizedError {
    case firebaseNotConfigured
    case emptyCatalog
    case invalidDocument(String)

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            "Firebase 설정을 확인해 주세요."
        case .emptyCatalog:
            "Firestore destinations 컬렉션에 여행지를 추가해 주세요."
        case let .invalidDocument(id):
            "여행지 데이터 형식이 올바르지 않습니다: \(id)"
        }
    }
}
