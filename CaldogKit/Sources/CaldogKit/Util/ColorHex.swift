import Foundation
import CoreGraphics

/// CGColor ↔ "#RRGGBB" 16진 문자열 변환 유틸.
public enum ColorHex {
    /// CGColor를 sRGB 기준 "#RRGGBB"로 변환. 변환 실패 시 회색 폴백.
    public static func string(from cgColor: CGColor?) -> String {
        guard let cgColor else { return "#8E8E93" }
        guard
            let srgb = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
            let comps = converted.components, comps.count >= 3
        else {
            return "#8E8E93"
        }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    /// "#RRGGBB" → (r,g,b) 0...1. 파싱 실패 시 nil.
    public static func rgb(from hex: String) -> (red: Double, green: Double, blue: Double)? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return (r, g, b)
    }

    private static func clamp(_ v: Int) -> Int { min(255, max(0, v)) }
}
