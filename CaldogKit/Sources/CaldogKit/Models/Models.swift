import Foundation
import SwiftData

/// 앱 전역 설정(단일 레코드). CloudKit 동기화 가능.
///
/// 재포지셔닝(위젯 중심) 이후 보조 메타데이터는 이 설정 하나로 축소되었다.
/// 일정 편집/태그/검색/스마트필터는 제거되었고(애플 캘린더에 위임), 위젯 구성은
/// SwiftData가 아니라 App Intents(WidgetConfigurationIntent)로 처리한다(SPEC §5).
@Model
public final class AppSettings {
    public var firstWeekday: Int = 1              // 1 = 일요일
    public var uses24HourTime: Bool = false
    public var createdAt: Date = Date.distantPast

    public init() {}
}

public enum CaldogSchema {
    /// 앱 ModelContainer에 등록할 모델 전체.
    public static let models: [any PersistentModel.Type] = [
        AppSettings.self,
    ]
}
