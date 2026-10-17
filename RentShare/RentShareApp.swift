import SwiftUI

// The distribution target includes only the live client, with no offline seed data.
@main
struct RentShareApp: App {
    var body: some Scene {
        WindowGroup { ConnectedRootView().tint(Brand.green) }
    }
}

enum Brand {
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 16/255, green: 36/255, blue: 31/255, alpha: 1)
            : UIColor(red: 243/255, green: 248/255, blue: 248/255, alpha: 1)
    })
    static let green = Color(red: 15/255, green: 81/255, blue: 50/255)
    static let mint = Color(red: 16/255, green: 185/255, blue: 129/255)
}
