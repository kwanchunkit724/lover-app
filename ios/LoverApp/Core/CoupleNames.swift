import Foundation

/// Names on the 我哋 card and in chat.
///
/// `kk_ensure_profile()` inserts `my_name = 我` and `partner_name = 對方`
/// when a row is missing, and it does not update those columns later.
/// A phone can show a real local name (onboarding or Sign in with Apple)
/// while `users.my_name` is still that default, so the partner sees 「我」.
///
/// Placeholders are never a display name and are never written over a real one.
enum CoupleNames {
    static let mePlaceholder = "我"
    static let partnerPlaceholder = "對方"
    static let missing = "…"
    static let maxLength = 40

    private static let placeholders: Set<String> = [mePlaceholder, partnerPlaceholder, missing]

    struct Identity: Equatable {
        var meName: String
        var partnerName: String
        var meInitial: String
        var partnerInitial: String

        var title: String { "\(meName) & \(partnerName)" }
    }

    enum Rejection: Equatable {
        case empty
        case placeholder
        case tooLong
    }

    /// Nil when `raw` is blank, too long, or one of the server defaults.
    static func persistable(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        guard !placeholders.contains(trimmed) else { return nil }
        return trimmed
    }

    static func rejection(of raw: String) -> Rejection? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maxLength { return .tooLong }
        if placeholders.contains(trimmed) { return .placeholder }
        return nil
    }

    static func message(for rejection: Rejection) -> String {
        switch rejection {
        case .empty:
            return "先寫你嘅名。"
        case .placeholder:
            return "唔好用「我」或者「對方」。"
        case .tooLong:
            return "名最多 40 個字。"
        }
    }

    /// NOT NULL column value. A real name passes through. A placeholder stays
    /// the existing default so this path does not invent a personal name.
    static func columnValue(_ raw: String, fallback: String) -> String {
        persistable(raw) ?? fallback
    }

    /// First real name wins. Defaults 「我」 / 「對方」 do not hide a later real name.
    static func display(preferred: String?, fallback: String?) -> String {
        if let name = persistable(preferred) { return name }
        if let name = persistable(fallback) { return name }
        return missing
    }

    static func initial(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return missing }
        return String(first)
    }

    /// `partnerMyName` is the partner's own `users.my_name`. `localPartnerName`
    /// is what this phone already calls them, used only while the remote
    /// value is still a placeholder.
    static func identity(myName: String?, partnerMyName: String?, localPartnerName: String?) -> Identity {
        let me = display(preferred: myName, fallback: nil)
        let partner = display(preferred: partnerMyName, fallback: localPartnerName)
        return Identity(
            meName: me,
            partnerName: partner,
            meInitial: initial(of: me),
            partnerInitial: initial(of: partner)
        )
    }

    /// Keep a real on-device name. Fill from Apple only when the local name
    /// is still a placeholder. Apple's given name is the one the user sees
    /// as 「kit」; family name is used only when the given name is empty.
    static func adoptingAppleName(
        myName: String,
        givenName: String?,
        familyName: String?,
        nickname: String?
    ) -> String {
        if let existing = persistable(myName) { return existing }
        if let given = persistable(givenName) { return given }
        if let nick = persistable(nickname) { return nick }
        let combined = [givenName, familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if let both = persistable(combined) { return both }
        return myName
    }

    static func profile(
        _ profile: UserProfile,
        givenName: String?,
        familyName: String?,
        nickname: String?
    ) -> UserProfile {
        var copy = profile
        copy.myName = adoptingAppleName(
            myName: profile.myName,
            givenName: givenName,
            familyName: familyName,
            nickname: nickname
        )
        return copy
    }
}
