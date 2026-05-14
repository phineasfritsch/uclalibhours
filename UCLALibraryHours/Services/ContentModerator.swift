import Foundation

// MARK: - Moderation Result

struct ModerationResult: Equatable {
    enum Reason: String, Equatable {
        case empty
        case tooShort
        case tooLong
        case profanity
        case hateSpeech
        case sexualContent
        case violenceOrThreat
        case personalInfo
        case externalLink
        case spamPattern
        case excessiveCaps
        case excessiveRepetition
        case disallowedCharacters
    }

    let allowed: Bool
    let reasons: [Reason]
    let sanitizedText: String

    var userFacingMessage: String {
        guard let first = reasons.first else { return "" }
        switch first {
        case .empty: return "Text can't be empty."
        case .tooShort: return "Text is too short."
        case .tooLong: return "Text is too long. Please shorten it."
        case .profanity, .hateSpeech, .sexualContent, .violenceOrThreat:
            return "This content violates our community guidelines. Please revise."
        case .personalInfo: return "Please remove personal info (email, phone, address) before submitting."
        case .externalLink: return "Links aren't allowed in submissions."
        case .spamPattern: return "This looks like spam. Please rewrite naturally."
        case .excessiveCaps: return "Please don't write in ALL CAPS."
        case .excessiveRepetition: return "Please avoid repeated characters or words."
        case .disallowedCharacters: return "This contains characters that aren't allowed."
        }
    }
}

// MARK: - Field Configurations

struct ModerationConfig {
    let minLength: Int
    let maxLength: Int
    let allowLinks: Bool
    let allowEmpty: Bool

    static let spaceName = ModerationConfig(minLength: 2, maxLength: 80, allowLinks: false, allowEmpty: false)
    static let building = ModerationConfig(minLength: 2, maxLength: 80, allowLinks: false, allowEmpty: false)
    static let floor = ModerationConfig(minLength: 0, maxLength: 40, allowLinks: false, allowEmpty: true)
    static let description = ModerationConfig(minLength: 20, maxLength: 1000, allowLinks: false, allowEmpty: false)
    static let reviewBody = ModerationConfig(minLength: 0, maxLength: 1000, allowLinks: false, allowEmpty: true)
}

// MARK: - Content Moderator

enum ContentModerator {

    // Single entry point. Sanitizes, then runs all rules.
    static func moderate(_ raw: String, config: ModerationConfig) -> ModerationResult {
        let cleaned = sanitize(raw)
        var reasons: [ModerationResult.Reason] = []

        // Length & empty
        if cleaned.isEmpty {
            if !config.allowEmpty { reasons.append(.empty) }
            return ModerationResult(allowed: reasons.isEmpty, reasons: reasons, sanitizedText: cleaned)
        }
        if cleaned.count < config.minLength { reasons.append(.tooShort) }
        if cleaned.count > config.maxLength { reasons.append(.tooLong) }

        // Character set
        if containsDisallowedCharacters(cleaned) { reasons.append(.disallowedCharacters) }

        // Categorized banned content
        let lower = cleaned.lowercased()
        let normalized = leetNormalize(lower)
        if matchesAny(normalized, list: BannedWords.hate) { reasons.append(.hateSpeech) }
        if matchesAny(normalized, list: BannedWords.sexual) { reasons.append(.sexualContent) }
        if matchesAny(normalized, list: BannedWords.violence) { reasons.append(.violenceOrThreat) }
        if matchesAny(normalized, list: BannedWords.profanity) { reasons.append(.profanity) }

        // PII
        if containsPII(cleaned) { reasons.append(.personalInfo) }

        // Links
        if !config.allowLinks && containsLink(cleaned) { reasons.append(.externalLink) }

        // Spam heuristics
        if isExcessiveCaps(cleaned) { reasons.append(.excessiveCaps) }
        if hasExcessiveRepetition(cleaned) { reasons.append(.excessiveRepetition) }
        if looksLikeSpam(cleaned) { reasons.append(.spamPattern) }

        // Deduplicate while preserving order
        var seen = Set<ModerationResult.Reason>()
        let unique = reasons.filter { seen.insert($0).inserted }

        return ModerationResult(allowed: unique.isEmpty, reasons: unique, sanitizedText: cleaned)
    }

    // MARK: - Sanitization

    static func sanitize(_ raw: String) -> String {
        // Strip zero-width and control characters except newline/tab.
        let stripped = raw.unicodeScalars.filter { scalar in
            if scalar.value == 0x0009 || scalar.value == 0x000A { return true }
            if scalar.value < 0x20 { return false }                      // C0 controls
            if (0x7F...0x9F).contains(scalar.value) { return false }     // DEL + C1 controls
            // Zero-width chars and bidi overrides used for spoofing
            let zw: Set<UInt32> = [0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
                                   0x2028, 0x2029, 0x202A, 0x202B, 0x202C,
                                   0x202D, 0x202E, 0x2060, 0xFEFF]
            if zw.contains(scalar.value) { return false }
            return true
        }
        var s = String(String.UnicodeScalarView(stripped))
        // Collapse runs of whitespace
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Character checks

    private static func containsDisallowedCharacters(_ s: String) -> Bool {
        // Reject text where > 30% of chars are outside common letter/number/punct ranges.
        // Catches keyboard-mash garbage and obscure scripts used for evasion.
        guard !s.isEmpty else { return false }
        var bad = 0
        var total = 0
        for scalar in s.unicodeScalars {
            total += 1
            let v = scalar.value
            let isLetter = CharacterSet.letters.contains(scalar)
            let isDigit = CharacterSet.decimalDigits.contains(scalar)
            let isCommonPunct = CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar)
                || CharacterSet.whitespacesAndNewlines.contains(scalar)
            // Allow emoji range broadly so people can decorate
            let isEmoji = (0x1F300...0x1FAFF).contains(v) || (0x2600...0x27BF).contains(v)
            if !(isLetter || isDigit || isCommonPunct || isEmoji) {
                bad += 1
            }
        }
        return Double(bad) / Double(total) > 0.30
    }

    // MARK: - Leet / obfuscation normalize

    static func leetNormalize(_ s: String) -> String {
        let map: [Character: Character] = [
            "0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a",
            "5": "s", "$": "s", "7": "t", "+": "t", "8": "b", "9": "g"
        ]
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            out.append(map[ch] ?? ch)
        }
        // Drop spacing/punct between letters so "f u c k" → "fuck"
        let collapsed = out.unicodeScalars.compactMap { scalar -> Character? in
            if CharacterSet.letters.contains(scalar) { return Character(scalar) }
            return nil
        }
        return String(collapsed)
    }

    private static func matchesAny(_ haystack: String, list: [String]) -> Bool {
        for needle in list where !needle.isEmpty {
            if haystack.contains(needle) { return true }
        }
        return false
    }

    // MARK: - PII

    private static func containsPII(_ s: String) -> Bool {
        let patterns = [
            // Email
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            // US phone: optional country, area code in (), dashes/spaces/dots
            "(?:\\+?1[\\s.-]?)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}",
            // SSN-like 9-digit grouped
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // Credit-card-ish: 13–19 digits with optional grouping
            "\\b(?:\\d[ -]*?){13,19}\\b"
        ]
        for p in patterns {
            if s.range(of: p, options: .regularExpression) != nil { return true }
        }
        return false
    }

    // MARK: - Links

    private static func containsLink(_ s: String) -> Bool {
        let pattern = "(?i)\\b(?:https?://|www\\.)\\S+|\\b[a-z0-9][a-z0-9-]*\\.(?:com|net|org|io|co|gov|edu|info|biz|app|dev|xyz|me|us)\\b"
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Spam heuristics

    private static func isExcessiveCaps(_ s: String) -> Bool {
        let letters = s.filter { $0.isLetter }
        guard letters.count >= 15 else { return false }
        let upper = letters.filter { $0.isUppercase }.count
        return Double(upper) / Double(letters.count) > 0.70
    }

    private static func hasExcessiveRepetition(_ s: String) -> Bool {
        // Same char repeated 6+ times: "aaaaaa", "!!!!!!"
        if s.range(of: "(.)\\1{5,}", options: .regularExpression) != nil { return true }
        // Same word repeated 4+ times in a row
        if s.range(of: "(?i)\\b(\\w+)\\b(?:\\s+\\1\\b){3,}", options: .regularExpression) != nil { return true }
        return false
    }

    private static func looksLikeSpam(_ s: String) -> Bool {
        let lower = s.lowercased()
        let spamPhrases = [
            "buy now", "click here", "limited time", "act now",
            "free money", "free gift", "make money fast", "work from home",
            "viagra", "casino", "crypto giveaway", "nft drop", "telegram me",
            "dm me", "whatsapp me", "follow me on", "subscribe to my",
            "promo code", "discount code", "use code"
        ]
        for phrase in spamPhrases where lower.contains(phrase) { return true }
        return false
    }
}

// MARK: - Banned Word Lists
// Conservative lists. Matched against leet-normalized lowercase text after
// spaces/punct are stripped, so "f.u.c.k" and "fvck" still get caught.

enum BannedWords {

    static let profanity: [String] = [
        "fuck", "fuk", "fvck", "shit", "sht", "bitch", "btch", "asshole",
        "bastard", "dick", "piss", "crap", "damn", "cunt", "twat",
        "wank", "bollocks", "bullshit", "motherfucker", "douchebag", "jackass"
    ]

    // Hate / slurs — kept obfuscated where reasonable but matched after leet-normalize.
    static let hate: [String] = [
        "nigger", "nigga", "faggot", "fag", "tranny", "retard", "retarded",
        "chink", "spic", "kike", "gook", "dyke", "wetback", "towelhead",
        "raghead", "kkk", "heilhitler", "whitepower", "blackpower"
    ]

    static let sexual: [String] = [
        "porn", "xxx", "nude", "nudes", "boobs", "tits", "pussy",
        "cock", "blowjob", "handjob", "anal", "cum", "horny",
        "onlyfans", "camgirl", "sexcam", "milf", "incest", "rape", "raped",
        "pedo", "pedophile", "loli", "underage"
    ]

    static let violence: [String] = [
        "killyou", "killyourself", "kys", "shootup", "bombthe",
        "stabhim", "stabher", "murderhim", "murderher",
        "lynchhim", "lynchher", "iwillkill", "iwillmurder",
        "schoolshoot", "schoolshooter"
    ]
}
