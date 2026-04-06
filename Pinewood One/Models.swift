import Foundation

struct MobileUser: Decodable {
    let userId: Int
    let email: String
    let name: String
    let onboardingStep: String
    let schoologyConnected: Bool
    let profilePictureUrl: String?
}

struct AuthUserSummary: Decodable {
    let userId: Int
    let email: String
    let name: String
}

struct AuthExchangeResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String
    let refreshExpiresIn: Int
    let tokenType: String
    let user: AuthUserSummary
}

struct ConvexTokenResponse: Decodable {
    let token: String
    let expiresIn: Int
}

struct WebSessionTicketResponse: Decodable {
    let ticket: String
    let expiresIn: Int
}

struct SchoologyStartResponse: Decodable {
    let authUrl: String
}

struct BannerMetadataResponse: Decodable {
    let imageUrl: String?
    let version: String
    let cacheTtlSeconds: Int
}

struct UpcomingAssignment: Identifiable, Decodable {
    let id: String
    let title: String
    let due: String
    let courseTitle: String
    let sectionTitle: String
    let assignmentDescription: String

    init(
        id: String,
        title: String,
        due: String,
        courseTitle: String,
        sectionTitle: String,
        assignmentDescription: String
    ) {
        self.id = id
        self.title = title
        self.due = due
        self.courseTitle = courseTitle
        self.sectionTitle = sectionTitle
        self.assignmentDescription = assignmentDescription
    }

    static func from(json: [String: Any]) -> UpcomingAssignment {
        let idValue = String(describing: json["id"] ?? json["assignment_id"] ?? UUID().uuidString)
        let title = (json["title"] as? String)
            ?? (json["name"] as? String)
            ?? "Untitled Assignment"
        let due = (json["due"] as? String) ?? "No due date"
        let courseTitle = (json["course_title"] as? String)
            ?? (json["courseTitle"] as? String)
            ?? "Unknown Course"
        let sectionTitle = (json["section_title"] as? String)
            ?? (json["sectionTitle"] as? String)
            ?? ""
        let description = (json["description"] as? String)
            ?? (json["assignment_description"] as? String)
            ?? ""

        return UpcomingAssignment(
            id: idValue,
            title: title,
            due: due,
            courseTitle: courseTitle,
            sectionTitle: sectionTitle,
            assignmentDescription: description
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let idValue = container.decodeLossyString(forKeys: [.id, .assignmentId, .assignmentIdSnake]) ?? UUID().uuidString
        let titleValue = container.decodeLossyString(forKeys: [.title, .name]) ?? "Untitled Assignment"
        let dueValue = container.decodeLossyString(forKeys: [.due]) ?? "No due date"
        let courseTitleValue = container.decodeLossyString(forKeys: [.courseTitle, .courseTitleSnake]) ?? "Unknown Course"
        let sectionTitleValue = container.decodeLossyString(forKeys: [.sectionTitle, .sectionTitleSnake]) ?? ""
        let descriptionValue = container.decodeLossyString(
            forKeys: [.assignmentDescription, .assignmentDescriptionSnake, .description]
        ) ?? ""

        id = idValue
        title = titleValue
        due = dueValue
        courseTitle = courseTitleValue
        sectionTitle = sectionTitleValue
        assignmentDescription = descriptionValue
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case assignmentId
        case assignmentIdSnake = "assignment_id"
        case title
        case name
        case due
        case courseTitle
        case courseTitleSnake = "course_title"
        case sectionTitle
        case sectionTitleSnake = "section_title"
        case assignmentDescription
        case assignmentDescriptionSnake = "assignment_description"
        case description
    }
}

struct MobileContext {
    let deviceId: String
    let platform: String
    let appVersion: String
    let locale: String
    let timezone: String

    static func current(deviceId: String) -> MobileContext {
        MobileContext(
            deviceId: deviceId,
            platform: "ios",
            appVersion: AppConfig.appVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKeys keys: [Key]) -> String? {
        for key in keys {
            if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
                return stringValue
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
            if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
                return boolValue ? "true" : "false"
            }
        }
        return nil
    }
}
