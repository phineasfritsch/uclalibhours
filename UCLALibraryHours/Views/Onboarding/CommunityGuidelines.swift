import Foundation

// MARK: - Static content for EULA / Community Guidelines / About
// Keeping these as `let`s rather than in a server-fetched config so they
// ship with the binary and Apple reviewers see exactly what users will see.

enum CommunityGuidelines {

    static let version = "1.0"

    static let summary = "UCLA Library Hours is a community-driven app. To keep it useful and safe for everyone, all posts and reviews must follow these rules."

    static let rules: [(title: String, body: String, icon: String)] = [
        (
            "Be respectful",
            "No harassment, bullying, threats, or hate speech of any kind, including content that targets people based on race, ethnicity, religion, gender, sexual orientation, disability, or any other protected characteristic.",
            "person.2.fill"
        ),
        (
            "Keep it appropriate",
            "No sexual content, nudity, violence, or content promoting self-harm. This is a study-spaces app for university students.",
            "checkmark.shield.fill"
        ),
        (
            "Protect privacy",
            "Don't share personal information (yours or anyone else's): phone numbers, addresses, emails, student IDs, or anything that could identify a specific individual.",
            "lock.fill"
        ),
        (
            "No spam or self-promotion",
            "No advertising, links to external sites, referral codes, or off-topic content. Reviews should be honest and based on real experience.",
            "envelope.badge.shield.half.filled"
        ),
        (
            "Be honest",
            "Don't post false information about study spaces, hours, or amenities. Don't impersonate others or create misleading content.",
            "hand.raised.fill"
        ),
        (
            "Report problems",
            "If you see content that violates these rules, tap the flag icon to report it. Our team reviews reports within 24 hours.",
            "flag.fill"
        )
    ]

    static let enforcementText = """
We use automated filtering and human review to enforce these guidelines. Content that violates them may be removed without notice. Repeated or severe violations may result in your account being restricted from posting. You can appeal moderation actions by emailing the address below.
"""

    static let contactEmail = "support@uclalibhours.app"
}

enum EULAContent {

    static let version = "1.0"

    static let title = "End User License Agreement"

    static let bodyMarkdown = """
**1. Acceptance.** By using UCLA Library Hours (the "App"), you agree to these terms. If you don't agree, please don't use the App.

**2. Acceptable Use.** You agree to follow our Community Guidelines. You are responsible for all content you submit, including space descriptions, reviews, and reports. You will not submit content that is unlawful, infringing, abusive, defamatory, hateful, obscene, threatening, or otherwise objectionable.

**3. Zero Tolerance for Objectionable Content.** We do not tolerate objectionable content or abusive users. Any user who repeatedly violates the Community Guidelines may have their submissions blocked.

**4. Reporting & Moderation.** You may flag objectionable content using the in-app reporting tools. We commit to reviewing reports within 24 hours and removing content or restricting users who violate these terms. You may also block users to prevent their content from appearing for you.

**5. License.** We grant you a limited, non-exclusive, non-transferable license to use the App on your devices for personal, non-commercial use.

**6. User Content.** You retain ownership of content you submit, but grant us a worldwide, non-exclusive license to host, display, and distribute it within the App.

**7. No Warranty.** The App is provided "as is" without warranty of any kind. We do not guarantee accuracy of crowd-sourced information.

**8. Limitation of Liability.** To the maximum extent permitted by law, we are not liable for any damages arising from your use of the App.

**9. Changes.** We may update these terms. Continued use after changes constitutes acceptance.

**10. Contact.** Questions or appeals: support@uclalibhours.app
"""
}
