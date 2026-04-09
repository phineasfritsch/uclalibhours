import Foundation

// MARK: - Library Location Info

struct LibraryLocationInfo {
    let lid: Int
    let address: String
    let specialInstructions: String?

    // MARK: URL helpers

    /// Opens in the Apple Maps app.
    var appleMapURL: URL {
        URL(string: "maps://?q=\(encodedAddress)") ?? fallbackAppleURL
    }

    /// Opens in the Google Maps app if installed, otherwise falls back to the web.
    var googleMapAppURL: URL {
        URL(string: "comgooglemaps://?q=\(encodedAddress)")!
    }

    var googleMapWebURL: URL {
        URL(string: "https://maps.google.com/?q=\(encodedAddress)")!
    }

    private var encodedAddress: String {
        address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
    }

    private var fallbackAppleURL: URL {
        URL(string: "https://maps.apple.com/?q=\(encodedAddress)")!
    }
}

// MARK: - Location Registry

extension LibraryLocationInfo {
    /// Keyed by the LibCal `lid`.
    static let byLid: [Int: LibraryLocationInfo] = [

        // Arts Library
        4690: LibraryLocationInfo(
            lid: 4690,
            address: "1400 Public Affairs Building, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Biomedical Library
        2081: LibraryLocationInfo(
            lid: 2081,
            address: "12-077 Center for Health Sciences, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Law Library
        4694: LibraryLocationInfo(
            lid: 4694,
            address: "385 Charles E Young Dr E, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Rosenfeld Management Library
        3280: LibraryLocationInfo(
            lid: 3280,
            address: "110 Westwood Plaza, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Music Library
        4696: LibraryLocationInfo(
            lid: 4696,
            address: "445 Charles E Young Dr E, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Powell Library
        2572: LibraryLocationInfo(
            lid: 2572,
            address: "10740 Dickson Plaza, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // Young Research Library (YRL)
        1916: LibraryLocationInfo(
            lid: 1916,
            address: "280 Charles E Young Dr N, Los Angeles, CA 90095",
            specialInstructions: nil
        ),

        // SEL/Boelter
        4702: LibraryLocationInfo(
            lid: 4702,
            address: "8270 Boelter Hall, Los Angeles, CA 90095",
            specialInstructions: "This library is on the 8th floor of Boelter Hall. Take the elevator to floor 8 — it is not visible from the main entrance."
        ),

        // SEL/Geology
        4703: LibraryLocationInfo(
            lid: 4703,
            address: "4697 Geology Building, Los Angeles, CA 90095",
            specialInstructions: "This library is in room 4697 of the Geology Building. Look for the signs near the 4th-floor elevators."
        ),

        // SRLF — off-campus storage facility, no public walk-in address
    ]
}
