import SwiftUI
import CaldogKit

extension Color {
    /// "#RRGGBB" 16진 문자열로 Color 생성. 파싱 실패 시 회색.
    init(hex: String) {
        if let rgb = ColorHex.rgb(from: hex) {
            self = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } else {
            self = .gray
        }
    }
}
