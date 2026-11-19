import Foundation

extension String {
    /// Case-insensitive, diacritic-insensitive containment: "jose" finds "José".
    func looselyContains(_ other: String) -> Bool {
        guard !other.isEmpty else { return true }
        return range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
