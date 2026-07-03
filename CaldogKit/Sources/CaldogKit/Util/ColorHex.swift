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

    /// 월 그리드 연속 바용 적응형 색.
    ///
    /// 캘린더 색을 그대로 텍스트/배경에 쓰면 옅은 색(노랑 등)에서 대비가 약해 제목이 안 보인다.
    /// 라이트/다크 각각 충분한 대비를 갖도록 텍스트는 진하게, 배경은 옅은/어두운 틴트로 분리한다.
    /// - Parameter dark: 다크 외형 여부.
    /// - Returns: (텍스트 RGB, 배경 RGB) 각 0...1. 파싱 실패 시 회색 기반.
    public static func barColors(from hex: String, dark: Bool)
        -> (text: (red: Double, green: Double, blue: Double),
            background: (red: Double, green: Double, blue: Double)) {
        let base = rgb(from: hex) ?? (0.55, 0.55, 0.55)
        func mix(_ c: Double, toward t: Double, _ f: Double) -> Double { c * (1 - f) + t * f }
        if dark {
            let text = (mix(base.red, toward: 1, 0.40), mix(base.green, toward: 1, 0.40), mix(base.blue, toward: 1, 0.40))
            let bg = (base.red * 0.30, base.green * 0.30, base.blue * 0.30)
            return (text, bg)
        } else {
            let text = (base.red * 0.62, base.green * 0.62, base.blue * 0.62)
            let bg = (mix(base.red, toward: 1, 0.84), mix(base.green, toward: 1, 0.84), mix(base.blue, toward: 1, 0.84))
            return (text, bg)
        }
    }
}
