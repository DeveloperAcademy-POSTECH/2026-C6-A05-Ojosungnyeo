//
//  String+KoreanParticle.swift
//  ddaddo
//

import Foundation

enum KoreanParticle {
    case subject
    case topic
    case direction

    fileprivate func suffix(for text: String) -> String {
        let finalConsonant = text.koreanFinalConsonant

        switch self {
        case .subject:
            return finalConsonant == nil ? "가" : "이"
        case .topic:
            return finalConsonant == nil ? "는" : "은"
        case .direction:
            return finalConsonant == nil || finalConsonant == 8 ? "로" : "으로"
        }
    }
}

extension String {
    func withKoreanParticle(_ particle: KoreanParticle) -> String {
        self + particle.suffix(for: self)
    }

    fileprivate var koreanFinalConsonant: Int? {
        guard let scalar = trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .last
        else { return nil }

        let value = Int(scalar.value)
        let hangulSyllableStart = 0xAC00
        let hangulSyllableEnd = 0xD7A3
        guard (hangulSyllableStart...hangulSyllableEnd).contains(value) else {
            return nil
        }

        let finalConsonant = (value - hangulSyllableStart) % 28
        return finalConsonant == 0 ? nil : finalConsonant
    }
}
