import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x24252F)
    static let card = Color(hex: 0x272D31)
    static let accent = Color(hex: 0x4482F9)
    static let inactiveTab = Color(hex: 0x292A35)
    static let placeholder = Color(hex: 0x848484)
    static let danger = Color(hex: 0xB00000)
    static let secondaryText = Color(hex: 0xA3A3A5)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
