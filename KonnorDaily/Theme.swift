import SwiftUI

extension Color {
    static let msMaroon = Color(red: 0.44, green: 0.04, blue: 0.12)
    static let msMaroonText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(red: 0.44, green: 0.04, blue: 0.12, alpha: 1)
        }
    )
    static let appText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .label
        }
    )
    static let appSecondaryText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .secondaryLabel
        }
    )
    static let appCorrectText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .systemGreen
        }
    )
    static let appErrorText = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .systemRed
        }
    )
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
