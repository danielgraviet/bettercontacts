import Domain
import Foundation

// Deterministic time fixtures shared by every test suite.
//
// 2001-01-01 was a Monday (UTC), which makes week and month boundaries easy
// to reason about: the week of January 1st runs January 1-7, the month starts
// on the 1st, and nothing overlaps a year boundary by accident.

let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
}()

/// 2001-01-01 00:00:00 UTC — the shared "now" for most tests.
let referenceNow = Date(timeIntervalSinceReferenceDate: 0)

func testDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    let components = DateComponents(year: year, month: month, day: day, hour: hour)
    return testCalendar.date(from: components) ?? referenceNow
}

/// Test-data builder in the style of Google SWE book chapter 12: sane
/// defaults for every field, and each test overrides only what it cares
/// about (see `ContactBuilder` examples in the book: newContact(firstName:)).
func makeContact(
    id: String = "contact-1",
    firstName: String = "Grace",
    lastName: String = "Hopper",
    organization: String? = "US Navy",
    phoneNumbers: [String] = ["555-123-4567"],
    emailAddresses: [String] = ["grace@example.com"],
    birthday: MonthDay? = nil,
    location: String? = nil,
    notes: String = "",
    tags: Set<String> = [],
    isCloseCircle: Bool = false,
    createdAt: Date = referenceNow,
    lastInteractionDate: Date? = nil
) -> Contact {
    Contact(
        id: id,
        firstName: firstName,
        lastName: lastName,
        organization: organization,
        phoneNumbers: phoneNumbers,
        emailAddresses: emailAddresses,
        birthday: birthday,
        location: location,
        notes: notes,
        tags: tags,
        isCloseCircle: isCloseCircle,
        createdAt: createdAt,
        lastInteractionDate: lastInteractionDate
    )
}

/// A deterministic stand-in for the on-device embedding model, in the spirit
/// of Google SWE book chapter 13: a *fake*, not a mock. It holds plain state,
/// records nothing, and verifies nothing — it simply embeds any text that
/// contains a known keyword as that keyword's vector, and reports no embedding
/// for text it does not understand.
struct FakeEmbedder: EmbeddingProviding {
    private let vectorsByKeyword: [(keyword: String, vector: [Double])]

    init(_ vectorsByKeyword: [String: [Double]]) {
        // Sorted so iteration order never depends on dictionary hashing.
        self.vectorsByKeyword = vectorsByKeyword
            .map { (keyword: $0.key, vector: $0.value) }
            .sorted { $0.keyword < $1.keyword }
    }

    func embedding(for text: String) -> [Double]? {
        for (keyword, vector) in vectorsByKeyword
        where text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return vector
        }
        return nil
    }
}
