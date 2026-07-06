import Foundation
import AppIntents
import WidgetKit

// MARK: - 위젯 버튼 AppIntents (앱 + 위젯 익스텐션 공용)
//
// 이 파일은 앱 타깃과 CaldogWidget 타깃 양쪽에 컴파일된다. Apple 가이드에 따라
// 인터랙티브(버튼) 인텐트는 양쪽 타깃에 포함해야 한다 — 익스텐션에만 있으면 앱 프로세스에서
// "Failed to fetch metadata for ShiftMonthIntent" 오류가 난다.
// 반대로 구성 인텐트(MonthWidgetConfig)는 익스텐션 전용이어야 한다: 앱에도 등록하면 위젯
// 편집 UI가 앱 쪽 등록으로 저장해 익스텐션이 구성값을 디코드하지 못한다(항상 기본값 표시).

/// 위젯 kind 문자열. 인텐트(양쪽 타깃)와 위젯 선언(익스텐션)이 공유한다.
enum CaldogWidgetKind {
    static let month = "CaldogMonthWidget"
}

// MARK: - 위젯 상호작용 상태 (현재 표시 중인 달 오프셋)
//
// 위젯의 ‹/› 버튼이 누적 오프셋을 갱신하고, 타임라인 공급자가 이를 읽어 표시 달을 결정한다.
// 인터랙티브 AppIntent와 공급자가 같은 저장소를 공유해야 하므로 App Group 스위트를 사용한다.
// (App Group capability 미연결 시에도 위젯 익스텐션 프로세스 내에서는 동작하며, 정식 동작에는
//  `group.dev.sijun.caldog` App Group 활성화가 필요하다 — docs/CAPABILITIES.md 참고.)
//
// 설계 메모: monthOffset은 전역 단일 값이라 같은 종류 위젯 인스턴스가 여러 개면 모두 같은 달을
// 함께 이동한다. 단순함을 위한 의도적 선택(대부분 월 위젯은 1개만 배치). 인스턴스별 분리가
// 필요해지면 구성 인텐트 파라미터로 오프셋을 옮긴다.
enum WidgetState {
    private static let key = "monthOffset"
    /// ±10년으로 제한해 극단 오프셋에서 date(byAdding:)가 nil이 되는 상황을 막는다.
    static let limit = 120
    private static let store = UserDefaults(suiteName: "group.dev.sijun.caldog") ?? .standard
    static var monthOffset: Int {
        get { store.integer(forKey: key) }
        set { store.set(max(-limit, min(limit, newValue)), forKey: key) }
    }
}

// MARK: - 인터랙티브 인텐트 (이전/다음 달, 이번 달)

struct ShiftMonthIntent: AppIntent {
    static var title: LocalizedStringResource { "월 이동" }
    @Parameter(title: "이동") var delta: Int
    init() {}
    init(delta: Int) { self.delta = delta }
    func perform() async throws -> some IntentResult {
        WidgetState.monthOffset += delta
        // 오프셋이 전역 공유 값이므로 같은 종류 위젯 전체를 갱신한다.
        WidgetCenter.shared.reloadTimelines(ofKind: CaldogWidgetKind.month)
        return .result()
    }
}

struct ResetMonthIntent: AppIntent {
    static var title: LocalizedStringResource { "이번 달로" }
    init() {}
    func perform() async throws -> some IntentResult {
        WidgetState.monthOffset = 0
        WidgetCenter.shared.reloadTimelines(ofKind: CaldogWidgetKind.month)
        return .result()
    }
}
