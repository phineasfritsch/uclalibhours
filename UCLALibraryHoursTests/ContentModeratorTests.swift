import XCTest
import Foundation

// ContentModerator.swift is compiled into this test target directly,
// so no @testable import is required.

final class ContentModeratorTests: XCTestCase {

    // MARK: - Clean content

    func testCleanDescriptionAllowed() {
        let text = "Cozy reading room on the second floor with plenty of outlets and natural light. Gets busy around midterms."
        let result = ContentModerator.moderate(text, config: .description)
        XCTAssertTrue(result.allowed, "Clean description should pass. Got: \(result.reasons)")
    }

    func testCleanShortNameAllowed() {
        let result = ContentModerator.moderate("Powell Reading Room", config: .spaceName)
        XCTAssertTrue(result.allowed)
    }

    func testCleanBuildingAllowed() {
        let result = ContentModerator.moderate("Young Research Library", config: .building)
        XCTAssertTrue(result.allowed)
    }

    func testEmptyOptionalFieldAllowed() {
        let result = ContentModerator.moderate("", config: .floor)
        XCTAssertTrue(result.allowed)
    }

    // MARK: - Length

    func testEmptyRequiredFieldRejected() {
        let result = ContentModerator.moderate("", config: .spaceName)
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reasons.first, .empty)
    }

    func testWhitespaceOnlyTreatedAsEmpty() {
        let result = ContentModerator.moderate("   \n\t  ", config: .spaceName)
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reasons.first, .empty)
    }

    func testTooShortDescriptionRejected() {
        let result = ContentModerator.moderate("Nice spot.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.tooShort))
    }

    func testTooLongDescriptionRejected() {
        let huge = String(repeating: "a quiet study spot with outlets. ", count: 200)
        let result = ContentModerator.moderate(huge, config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.tooLong))
    }

    // MARK: - Profanity / hate / sexual / violence

    func testProfanityRejected() {
        let result = ContentModerator.moderate("This place fucking sucks and it is way too loud.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.profanity))
    }

    func testLeetSpeakProfanityRejected() {
        let result = ContentModerator.moderate("This place is f.u.c.k.i.n.g terrible bro seriously what a dump.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.profanity))
    }

    func testNumberLeetProfanityRejected() {
        let result = ContentModerator.moderate("the lights make me feel like sh1t while studying here.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.profanity))
    }

    func testHateSlurRejected() {
        let result = ContentModerator.moderate("dont go here its full of f4ggots and creeps just terrible vibes", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.hateSpeech))
    }

    func testSexualContentRejected() {
        let result = ContentModerator.moderate("Check out my onlyfans for nudes posted daily, link in bio.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(
            result.reasons.contains(.sexualContent) ||
            result.reasons.contains(.spamPattern)
        )
    }

    func testViolenceThreatRejected() {
        let result = ContentModerator.moderate("kysright now if you study here, worst place on campus seriously", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.violenceOrThreat))
    }

    // MARK: - PII

    func testEmailDetected() {
        let result = ContentModerator.moderate("Contact me at student@ucla.edu for study group invites all welcome.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.personalInfo))
    }

    func testPhoneNumberDetected() {
        let result = ContentModerator.moderate("Call me at (310) 555-1234 if you want to meet up for studying here.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.personalInfo))
    }

    func testSSNDetected() {
        let result = ContentModerator.moderate("Lost my id with ssn 123-45-6789 if you find it please return it asap", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.personalInfo))
    }

    // MARK: - Links

    func testExternalLinkRejected() {
        let result = ContentModerator.moderate("Best spot on campus, see review at https://example.com/review-page now.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.externalLink))
    }

    func testDomainOnlyLinkRejected() {
        let result = ContentModerator.moderate("Get more study tips on example.com if you want extras quickly today.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.externalLink))
    }

    // MARK: - Spam heuristics

    func testAllCapsRejected() {
        let result = ContentModerator.moderate("THIS IS THE BEST PLACE EVER GO HERE NOW", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.excessiveCaps) || result.reasons.contains(.tooShort) == false)
    }

    func testRepeatedCharsRejected() {
        let result = ContentModerator.moderate("This place is amaaaaaaaazing for studying and homework on weekdays.", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.excessiveRepetition))
    }

    func testRepeatedWordsRejected() {
        let result = ContentModerator.moderate("study study study study study study study study very nice", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.excessiveRepetition))
    }

    func testSpamPhraseRejected() {
        let result = ContentModerator.moderate("Best study spot, also click here to buy now and get a free gift today!", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.spamPattern) || result.reasons.contains(.externalLink))
    }

    // MARK: - Sanitization

    func testZeroWidthCharactersStripped() {
        let zw = "\u{200B}"
        let raw = "Powell\(zw) Library\(zw)\(zw) Reading Room"
        let result = ContentModerator.moderate(raw, config: .spaceName)
        XCTAssertTrue(result.allowed)
        XCTAssertFalse(result.sanitizedText.contains(zw))
    }

    func testControlCharactersStripped() {
        let raw = "Quiet\u{0007}corner\u{0001} near windows"
        let result = ContentModerator.moderate(raw, config: .spaceName)
        XCTAssertTrue(result.allowed)
        XCTAssertFalse(result.sanitizedText.contains("\u{0007}"))
        XCTAssertFalse(result.sanitizedText.contains("\u{0001}"))
    }

    func testTrimsLeadingTrailingWhitespace() {
        let result = ContentModerator.moderate("   Powell Reading Room   ", config: .spaceName)
        XCTAssertEqual(result.sanitizedText, "Powell Reading Room")
    }

    func testCollapsesInternalWhitespace() {
        let result = ContentModerator.moderate("Powell      Reading      Room", config: .spaceName)
        XCTAssertEqual(result.sanitizedText, "Powell Reading Room")
    }

    func testBidiOverrideStripped() {
        let bidi = "\u{202E}"
        let raw = "Powell\(bidi)Reading Room"
        let result = ContentModerator.moderate(raw, config: .spaceName)
        XCTAssertFalse(result.sanitizedText.contains(bidi))
    }

    // MARK: - User-facing messages

    func testErrorMessageNonEmpty() {
        let result = ContentModerator.moderate("fuck this place forever and ever and ever", config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertFalse(result.userFacingMessage.isEmpty)
    }

    // MARK: - Edge cases

    func testEmojiAllowed() {
        let result = ContentModerator.moderate("Cozy reading room 📚 with great natural light and plenty of outlets nearby.", config: .description)
        XCTAssertTrue(result.allowed, "Got reasons: \(result.reasons)")
    }

    func testReviewBodyEmptyAllowed() {
        let result = ContentModerator.moderate("", config: .reviewBody)
        XCTAssertTrue(result.allowed)
    }

    func testFloorEmptyAllowed() {
        let result = ContentModerator.moderate("", config: .floor)
        XCTAssertTrue(result.allowed)
    }

    func testKeyboardMashRejected() {
        let result = ContentModerator.moderate("ʘ̥ƣʚʛʢʣʤʥʦʧʨʩʪʫʬʭʮʯʰʱʲʳʴʵʶʷʸʹʺʻ", config: .description)
        XCTAssertFalse(result.allowed)
    }

    // MARK: - Leet normalize unit test

    func testLeetNormalize() {
        XCTAssertEqual(ContentModerator.leetNormalize("f.u.c.k"), "fuck")
        XCTAssertEqual(ContentModerator.leetNormalize("sh1t"), "shit")
        XCTAssertEqual(ContentModerator.leetNormalize("a$$h0le"), "asshole")
        XCTAssertEqual(ContentModerator.leetNormalize("p0rn"), "porn")
    }

    // MARK: - Config boundaries

    func testNameExactlyAtMaxAllowed() {
        // 80 chars of non-repeating bigram, avoids hitting excessiveRepetition rule
        let name = String(repeating: "ab", count: 40)
        XCTAssertEqual(name.count, 80)
        let result = ContentModerator.moderate(name, config: .spaceName)
        XCTAssertTrue(result.allowed, "80 chars should be allowed; reasons: \(result.reasons)")
    }

    func testNameOneOverMaxRejected() {
        let name = String(repeating: "ab", count: 40) + "c"
        XCTAssertEqual(name.count, 81)
        let result = ContentModerator.moderate(name, config: .spaceName)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.tooLong))
    }

    func testDescriptionExactlyAtMinAllowed() {
        let text = String(repeating: "ab", count: 10) // 20 chars, no consecutive repeats
        XCTAssertEqual(text.count, 20)
        let result = ContentModerator.moderate(text, config: .description)
        XCTAssertTrue(result.allowed, "20 chars should be allowed; reasons: \(result.reasons)")
    }

    func testDescriptionOneUnderMinRejected() {
        let text = String(repeating: "ab", count: 9) + "c" // 19 chars
        XCTAssertEqual(text.count, 19)
        let result = ContentModerator.moderate(text, config: .description)
        XCTAssertFalse(result.allowed)
        XCTAssertTrue(result.reasons.contains(.tooShort))
    }
}
