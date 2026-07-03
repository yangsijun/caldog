# caldog 기능 명세서

> 버전 0.3 · 재포지셔닝 2026-06-23: 위젯 중심
> 대상 플랫폼: iOS 26 / iPadOS 26 / macOS 26 이상
> 기술: SwiftUI · SwiftData · EventKit · WidgetKit · App Intents · CloudKit

---

## 1. 개요

### 1.1 앱 정체성
**caldog**는 **애플 캘린더 사용자를 위한 더 나은 위젯(better widgets for Apple Calendar users)** 이다.

caldog의 핵심 가치는 앱 자체가 아니라 **위젯**에 있다. 앱은 위젯을 뒷받침하는 **얇은 컴패니언(thin companion)** 으로, 세 가지 역할만 한다:
1. 캘린더 접근 권한 요청
2. 빠른 한눈보기 월 뷰 제공
3. 위젯 구성(configure)

일정 생성/수정/삭제는 **애플 캘린더에 위임**한다. caldog는 읽기 전용 뷰어이자 위젯 컨트롤 패널이다.

caldog는 별도의 일정 백엔드를 두지 않는다. 일정의 원본은 항상 시스템 캘린더(EventKit)이며, 따라서 애플 캘린더 앱, 기타 캘린더 앱, iCloud로 동기화된 모든 기기와 데이터가 자연스럽게 일치한다.

### 1.2 목표
- **위젯 경험**: 홈 화면/잠금화면/알림센터에서 월 캘린더와 일정을 애플 캘린더보다 더 잘 보여주는 위젯 제공.
- **얇은 컴패니언 앱**: 권한 요청 + 한눈보기 월 뷰 + 위젯 구성. 그 이상은 하지 않는다.
- **위임**: 일정 편집이 필요할 때는 애플 캘린더를 열어준다.

### 1.3 지원 플랫폼 및 최소 OS
| 플랫폼 | 최소 버전 | 비고 |
|--------|-----------|------|
| iOS | 26.0+ | iPhone |
| iPadOS | 26.0+ | iPad |
| macOS | 26.0+ | Mac (Apple Silicon/Intel) |

> 최신 OS 전용으로 설계한다. 구형 OS 가용성 분기(`if #available`) 부담 없이 최신 SwiftUI/SwiftData/WidgetKit/EventKit API를 사용한다.

### 1.4 핵심 가치 제안
- **애플 캘린더보다 나은 위젯**: 연속 다중일 이벤트 바, 테마·밀도 옵션, 표시 캘린더 필터, 인터랙티브 월 탐색 — 기본 위젯이 제공하지 않는 기능.
- **신뢰할 수 있는 단일 진실 공급원**: 일정 데이터는 시스템 캘린더(EventKit) 하나뿐. 데이터 중복/불일치 없음.
- **제로 설정 동기화**: iCloud 캘린더 사용 시 별도 계정/로그인 없이 모든 기기 동기화.
- **플랫폼 네이티브**: WidgetKit + App Intents 표준을 그대로 따른다.

### 1.5 용어 정의
| 용어 | 의미 |
|------|------|
| 이벤트(Event) | 시작/종료 시각을 가진 일정. EventKit의 `EKEvent`. |
| 캘린더(Calendar) | 이벤트를 담는 묶음(예: "개인", "업무"). `EKCalendar`. |
| 소스(Source) | 캘린더가 속한 계정(iCloud, On My Mac, 구독 등). `EKSource`. |
| 알람(Alarm) | 이벤트에 붙는 시스템 알림 설정. `EKAlarm`. (caldog가 직접 관리하지 않음) |
| 반복 규칙(Recurrence) | 일정의 반복 패턴. `EKRecurrenceRule`. |
| 컴패니언 앱 | caldog의 앱 타깃. 권한·월 뷰·위젯 구성만 담당하는 얇은 앱. |
| 위젯 | WidgetKit 기반의 홈/잠금화면 위젯. caldog의 핵심 제품. |

---

## 2. 아키텍처 원칙

### 2.1 데이터 소유권 (가장 중요한 원칙)
> **애플 캘린더(EventKit)가 일정의 원본(source of truth)이다. SwiftData는 앱 설정만 저장한다. 위젯 구성은 App Intents(WidgetConfigurationIntent)로 처리한다.**

- caldog는 일정 본문(제목/시간/장소/참석자/반복/알람 등)을 **SwiftData에 복제 저장하지 않는다.** 항상 `EKEventStore`에서 직접 읽는다.
- caldog는 일정을 **쓰지 않는다.** 모든 일정 생성/수정/삭제는 애플 캘린더에 위임한다.
- 멀티 디바이스 동기화 중 **일정 데이터의 동기화는 iCloud 캘린더가 담당**한다(caldog가 직접 동기화하지 않음).
- **SwiftData(+CloudKit)** 는 앱 설정(`AppSettings`)만 저장한다.
- **위젯 구성**(표시 캘린더, 테마, 밀도 등)은 WidgetKit의 `AppIntentConfiguration` + `WidgetConfigurationIntent`로 처리한다. SwiftData에 저장하지 않는다.

### 2.2 책임 분리
| 데이터 | 저장소 | 동기화 경로 |
|--------|--------|-------------|
| 이벤트·캘린더·알람·반복 | EventKit (시스템 DB) | iCloud 캘린더 (OS가 처리) |
| 앱 설정 (주 시작 요일, 24h 표기) | SwiftData | CloudKit private DB (선택적) |
| 위젯 구성 (표시 캘린더, 테마, 밀도) | App Intents / WidgetConfigurationIntent | WidgetKit 자체 관리 |
| 위젯 월 탐색 상태 (현재 표시 월) | App Group 공유 컨테이너 | 앱 ↔ 위젯 실시간 공유 |

### 2.3 데이터 흐름 (개념도)

```
        ┌──────────────────────────────────────────────┐
        │            애플 캘린더 (시스템 DB)             │
        │   EKEventStore  ─  EKEvent / EKCalendar ...   │
        └──────────────────▲────────────────────────────┘
                           │  읽기 전용 (쓰기 없음)
                           │
   ┌───────────────────────┴──────────┐
   │          caldog 컴패니언 앱        │
   │  (SwiftUI 월 뷰 + 위젯 구성 화면)  │
   └───────┬──────────────────────────┘
           │ App Group 공유 컨테이너
           ▼
   ┌──────────────────────────────────┐
   │       CaldogWidget 익스텐션       │
   │  (WidgetKit — 위젯 렌더링)        │
   │  - EventKit 직접 읽기             │
   │  - App Group에서 탐색 상태 수신   │
   └──────────────────────────────────┘

   ┌──────────────────────────────────┐
   │      SwiftData (앱 설정만)        │── CloudKit (선택적) ──▶ 다른 기기
   │   AppSettings: firstWeekday,     │
   │   uses24HourTime                 │
   └──────────────────────────────────┘
```

### 2.4 위젯 데이터 공유
위젯 익스텐션은 앱과 분리된 프로세스다. 위젯은 자체적으로 EventKit에 접근해 이벤트를 읽고, **App Group** 컨테이너를 통해 앱이 기록한 월 탐색 상태(현재 표시 월)를 수신한다. 위젯 구성(표시 캘린더, 테마, 밀도)은 `WidgetConfigurationIntent`의 파라미터로 저장되며 App Group을 거치지 않는다.

---

## 3. 데이터 모델

### 3.1 EventKit 매핑 (원본 데이터, caldog가 저장하지 않음)
caldog가 **읽는** EventKit 엔티티와 노출 필드 (모두 읽기 전용 — 편집은 애플 캘린더에 위임):

| 엔티티 | 주요 필드 | caldog 사용 |
|--------|-----------|-------------|
| `EKEvent` | `title`, `startDate`, `endDate`, `isAllDay`, `location`, `notes`, `url`, `timeZone`, `calendar`, `alarms`, `recurrenceRules`, `eventIdentifier` | 읽기 전용 (편집은 애플 캘린더에 위임) |
| `EKCalendar` | `title`, `cgColor`, `type`, `source`, `allowedEntityTypes`, `isImmutable` | 표시·필터 |
| `EKSource` | `title`, `sourceType` | 캘린더 그룹핑 표시 |
| `EKAlarm` | `relativeOffset`, `absoluteDate` | 표시 전용 (설정은 애플 캘린더에 위임) |
| `EKRecurrenceRule` | `frequency`, `interval` | 표시 전용 |

> 참석자(`EKParticipant`), 구조화 위치(`structuredLocation`), 가용성(`availability`) 등 고급 필드는 앱 내 편집 UI가 없으므로 필요 시 표시 전용으로만 노출한다.

### 3.2 SwiftData 보조 모델 (앱 설정 전용)
> 기존 템플릿의 `caldog/caldog/Item.swift`는 삭제하고 `AppSettings` 하나로 대체한다.

- **`AppSettings`** — 단일 레코드. 앱 전역 설정.
  - `firstWeekday: Int` — 주 시작 요일 (0=일요일, 1=월요일 …). 기본값 0.
  - `uses24HourTime: Bool` — 24시간 표기 여부. 기본값은 시스템 설정 따름.

> CloudKit 동기화를 위해 모든 속성은 기본값 또는 옵셔널을 갖는다.

> **위젯 구성은 SwiftData에 없다.** 표시 캘린더, 강조 색, 테마, 밀도 등 위젯별 설정은 `WidgetConfigurationIntent` 파라미터로 관리된다(§5 참조).

---

## 4. 기능 명세 (Functional)

각 기능은 **설명 + 수용 기준(AC)** 으로 기술한다.

### 4.1 권한 · 온보딩
**설명**: 최초 실행 시 캘린더 읽기 접근 권한을 요청한다. caldog는 캘린더 데이터를 **읽기만** 하므로, EventKit의 읽기 접근(`requestFullAccessToEvents`)을 요청한다.

**AC**
- 첫 실행 시 권한 요청 전, 왜 권한이 필요한지("홈 화면 위젯에 일정을 표시하기 위해") 설명하는 사전 안내 화면을 보여준다.
- 권한 허용 시 즉시 캘린더 데이터를 로드해 월 뷰를 표시한다.
- 권한 거부 시: 기능 제한 상태 화면 + "설정에서 권한 변경" 딥링크 제공. 앱이 크래시하거나 빈 화면으로 멈추지 않는다.
- 권한 상태 변경(설정에서 변경)을 앱 복귀 시 감지해 화면을 갱신한다.
- 미리알림 권한은 요청하지 않는다. caldog는 미리알림(`EKReminder`)을 다루지 않는다.

### 4.2 캘린더 보기 (한눈보기 월 뷰)
**설명**: 앱 내 유일한 캘린더 뷰는 **월 뷰**다. 빠른 한눈보기용이며, 상세 탐색은 위젯이나 애플 캘린더에서 한다. 주/일/목록(아젠다) 뷰는 제공하지 않는다(§11 범위 밖).

**AC**
- 6주 그리드, 오늘 날짜 강조, 각 날짜 셀에 해당일 이벤트 표시(점 또는 짧은 제목 칩).
- 종일 이벤트 및 다중일 이벤트는 연속 막대(continuous bar)로 표시 — 애플 캘린더 스타일.
- 이전/다음 월 이동: 스와이프 제스처 + 헤더 영역의 `<` `>` 버튼.
- "오늘" 버튼으로 현재 월로 즉시 복귀.
- 날짜 탭 시 해당 일의 이벤트 목록(간단한 인라인 목록)을 하단 시트 또는 인라인 영역에 표시.
- 이벤트 탭 시 → **애플 캘린더로 이동(§4.3)**.
- 표시 대상 캘린더는 시스템에 등록된 캘린더 전체를 기본으로 표시.
- 권한 미허용/이벤트 없음 상태를 명확히 표시.
- `.EKEventStoreChanged` 알림 수신 시 즉시 데이터 갱신.

### 4.3 애플 캘린더로 위임 (Jump to Apple Calendar)
**설명**: caldog는 일정을 생성, 수정, 삭제하지 않는다. 이벤트나 날짜를 탭하면 **애플 캘린더를 열어** 사용자가 직접 편집하도록 위임한다.

**AC**
- 이벤트 탭 시: iOS에서 `calshow:<timestamp>` URL 스킴으로 애플 캘린더의 해당 이벤트 시점으로 이동.
- 날짜 탭 후 "새 일정 추가" 버튼 탭 시: 같은 방식으로 애플 캘린더 열기.
- 애플 캘린더를 열 수 없는 환경(macOS 등)에서는 해당 버튼을 표시하지 않거나 비활성화한다.
- caldog 앱 내에 `EKEventEditViewController` 또는 커스텀 이벤트 편집 UI를 두지 않는다.
- 앱에서 EventKit의 `save(_:span:commit:)` 또는 `remove(_:span:commit:)` 호출 없음.

### 4.4 알림
**설명**: caldog는 자체 알림 레이어를 갖지 않는다. 이벤트에 설정된 `EKAlarm`은 시스템이 직접 발송하며(앱 개입 없음), caldog는 `UserNotifications` 프레임워크를 사용하지 않는다.

> EKAlarm(시스템 발송) 리마인더는 caldog와 무관하게 계속 동작한다. 사용자가 애플 캘린더에서 알람을 설정하면 그대로 울린다.

> 참고 (이슈 7 결정): 원격 푸시는 사용하지 않는다. 기존 템플릿의 `aps-environment` 엔타이틀먼트와 `remote-notification` 백그라운드 모드는 **제거**한다.

### 4.5 표시 캘린더 선택
**설명**: 위젯에서 어떤 `EKCalendar`를 표시할지 선택한다. 이는 앱 내 설정 화면이 아니라 **위젯 구성(WidgetConfigurationIntent)** 에서 처리한다(§5.2 참조).

앱 내 월 뷰는 시스템에 등록된 모든 캘린더를 표시한다. 앱 내 캘린더 on/off 토글은 별도로 두지 않는다.

---

## 5. 위젯 명세 (WidgetKit) — 핵심 제품

> 위젯은 caldog의 핵심 제품이다. 이 섹션이 명세의 중심이다.

**설명**: 전 플랫폼에서 **월 캘린더 + 이벤트**를 보여주는 위젯을 제공한다. 인터랙티브 월 탐색, 연속 다중일 이벤트 바, 구성 가능한 표시 캘린더·테마·밀도를 특징으로 한다.

### 5.1 지원 패밀리(크기) / 플랫폼
| 패밀리 | iOS | iPadOS | macOS | 내용 |
|--------|-----|--------|-------|------|
| `systemSmall` | ✓ | ✓ | ✓ | 오늘 날짜 + 다음 이벤트 요약 |
| `systemMedium` | ✓ | ✓ | ✓ | 주간 미니 그리드 + 오늘 이벤트 목록 |
| `systemLarge` | ✓ | ✓ | ✓ | **월 그리드 + 연속 이벤트 바** (핵심) |
| `systemExtraLarge` | – | ✓ | ✓ | 월 그리드 확대 + 이벤트 제목 상세 표시 |
| `accessoryRectangular`/`accessoryCircular`/`accessoryInline` | (v0.1 제외) | – | – | 잠금화면 위젯 — 향후 버전 (이슈 8 결정) |

### 5.2 현재 위젯 핵심 기능 (구현 완료 기준)

**5.2.1 월 그리드 & 이벤트 표시**

**AC**
- 현재 월 6주 그리드, 오늘 날짜 강조.
- `systemLarge` / `systemExtraLarge`: 날짜 셀에 이벤트 **연속 제목 바(continuous title bar)** 표시 — 다중일 이벤트가 날짜 경계를 넘어 가로로 이어지는 애플 캘린더 스타일.
- `systemSmall` / `systemMedium`: 날짜 셀에 점 또는 간단한 제목 칩 표시.
- 이벤트 없는 날/권한 미허용 상태를 위젯 내에서 명확히 표시.

**5.2.2 인터랙티브 월 탐색 (App Intents + App Group)**

**AC**
- 위젯 내 `<` (이전 월), `>` (다음 월), `오늘` 버튼을 탭하면 위젯이 표시하는 월이 전환된다.
- 월 전환은 **`AppIntent`** 를 통해 처리되며, 현재 표시 월은 **App Group** 공유 컨테이너에 기록된다.
- 앱이 같은 App Group을 통해 위젯 탐색 상태를 읽어 월 뷰를 동기화한다.
- 탐색 인터랙션 후 위젯 타임라인이 즉시 갱신된다(`WidgetCenter.reloadTimelines`).

**5.2.3 딥링크**

**AC**
- 위젯 탭(날짜 또는 이벤트 바) 시 caldog 앱이 열리며 해당 날짜의 월 뷰로 이동.
- URL 스킴 또는 `widgetURL` 사용 (예: `caldog://date/2026-06-23`).

**5.2.4 타임라인 갱신**

**AC**
- 자정 경계, 인터랙티브 탐색, 앱에서 `WidgetCenter.reloadTimelines` 호출 시 갱신.
- `.EKEventStoreChanged` 알림 수신 시 앱이 위젯 타임라인을 리로드.
- 시스템 갱신 예산 내에서 동작.

### 5.3 우선 신규 위젯 기능 (핵심 로드맵)

다음 두 기능은 위젯을 차별화하는 핵심 신규 기능이다.

---

**5.3.1 표시 캘린더 선택/필터 (EKCalendar 피커)**

**설명**: 사용자가 이 위젯 인스턴스에서 **어떤 캘린더를 표시할지** 선택한다. `WidgetConfigurationIntent` 파라미터로 구현하며, WidgetKit 구성 UI에서 캘린더 목록을 피커로 보여준다.

**구현 방향**
- `EKCalendar`를 `AppEntity` + `EntityQuery`로 래핑하여 App Intents 시스템에 등록.
- `WidgetConfigurationIntent`의 파라미터로 `[CalendarEntity]` (다중 선택) 추가.
- 선택된 캘린더 식별자 집합으로 위젯 타임라인 렌더링 시 이벤트를 필터링.
- 선택하지 않을 경우(기본값): 시스템 전체 캘린더 표시.

**AC**
- 위젯 길게 누르기 → "위젯 편집" 에서 캘린더 목록(이름 + 색상)이 다중 선택 피커로 표시된다.
- 선택된 캘린더의 이벤트만 위젯 그리드에 나타난다.
- 기본값(미선택)은 전체 캘린더를 표시한다.
- 시스템에서 캘린더가 추가/삭제되면 `EntityQuery`가 최신 목록을 반영한다.
- 각 위젯 인스턴스는 독립적인 캘린더 선택 상태를 가진다(위젯 인스턴스별 구성).

---

**5.3.2 디자인 테마 / 밀도 옵션**

**설명**: 위젯의 시각 스타일과 정보 밀도를 사용자가 선택할 수 있다. `WidgetConfigurationIntent` 파라미터로 구현한다.

**파라미터**
- **강조 색(accent color)**: 오늘 날짜 강조, 이벤트 바 기본 색 등에 사용되는 색상. 시스템 색상 팔레트 또는 캘린더 색상 따름 옵션 포함.
- **정보 밀도(density)**: `comfortable` / `compact` 두 단계.
  - `comfortable`: 날짜 셀 높이 넉넉, 이벤트 바에 제목 텍스트 표시, 레인 수 넓음.
  - `compact`: 날짜 셀 높이 좁음, 이벤트 바는 색상+점 표시(제목 생략), 더 많은 날짜를 좁은 공간에 표시.

**AC**
- 위젯 편집 화면에서 강조 색 선택기와 밀도 옵션(comfortable/compact)을 제공한다.
- `comfortable` 모드: 이벤트 바에 제목이 잘려도 표시되며, 최소 3개 레인을 날짜 셀 내 수직 배치.
- `compact` 모드: 이벤트 바는 색상 블록 또는 점으로 축약 표시. 동일 공간에 더 많은 이벤트 레인 수용 가능.
- 밀도 변경 시 위젯이 즉시 새 레이아웃으로 렌더링된다.
- 강조 색 변경 시 오늘 강조 및 이벤트 기본 색에 즉시 반영된다.
- `systemSmall`은 밀도 옵션 미적용(공간 부족). `systemMedium` 이상에서만 노출.

---

### 5.4 위젯 데이터 접근 원칙
- 위젯은 EventKit에서 직접 이벤트를 읽는다(앱을 거치지 않음).
- 월 탐색 상태는 **App Group** 공유 컨테이너로 앱과 공유한다.
- 위젯 구성(캘린더 선택, 테마, 밀도)은 `WidgetConfigurationIntent` 파라미터에 저장되며 별도 공유 컨테이너가 필요 없다.

---

## 6. 동기화 명세

### 6.1 일정 데이터
- 동기화 주체: **iCloud 캘린더(OS)**. caldog는 동기화 코드를 작성하지 않는다.
- caldog는 EventKit 변경 알림(`.EKEventStoreChanged`)을 구독해 외부 변경(다른 기기/앱)을 감지하고 월 뷰·위젯을 갱신한다.
- 오프라인 시 EventKit 로컬 캐시로 읽기 가능하며, 온라인 복귀 시 OS가 동기화.

### 6.2 앱 설정
- 동기화 주체: **CloudKit private database** (SwiftData의 CloudKit 통합 사용, 선택적).
- 대상: `AppSettings` (firstWeekday, uses24HourTime).
- 충돌 정책: 마지막 쓰기 우선(last-writer-wins) 기본.
- 기존 `caldog.entitlements`에 CloudKit 서비스가 이미 설정되어 있어 이를 활용한다(컨테이너 식별자 설정 필요).

---

## 7. 플랫폼별 UX

| 측면 | iOS (iPhone) | iPadOS | macOS |
|------|--------------|--------|-------|
| 레이아웃 | 단일 컬럼, 월 뷰 중심 | 월 뷰 + 사이드 패널 | 창 기반, 월 뷰 중심 |
| 입력 | 터치 중심 | 터치 + 포인터 + 하드웨어 키보드 | 마우스/트랙패드 + 키보드 |
| 탐색 | 스와이프 + 헤더 버튼 | 스와이프 + 헤더 버튼 | 클릭 + 키보드 |
| 일정 편집 | 애플 캘린더 위임 (`calshow:`) | 애플 캘린더 위임 | 애플 캘린더 위임 (가능 시) |
| 위젯 | 홈/잠금화면 | 홈/잠금화면 | 알림 센터/데스크탑 |
| 부가 | – | 멀티태스킹 지원 | 메뉴바 항목(선택적), 키보드 단축키 |

**AC**
- 동일 코드베이스에서 플랫폼별 적응형 레이아웃을 사용한다.
- 애플 캘린더 열기(`calshow:`) URL 스킴이 동작하지 않는 환경(macOS 등)에서는 해당 UI 요소를 조건부로 표시/비활성화한다.

---

## 8. 비기능 요구사항

- **성능**: 수천 건 이벤트/월 전환 시 스크롤 60fps 목표. EventKit 조회는 가시 범위 기반으로 페치하고 백그라운드 큐에서 수행.
- **접근성**: VoiceOver 라벨, Dynamic Type, 충분한 명도 대비, 색상에만 의존하지 않는 이벤트 구분(색+레이블).
- **개인정보·보안**: 캘린더 데이터는 외부 서버로 반출하지 않는다(시스템 캘린더 + 사용자 본인 iCloud/CloudKit만 사용). 권한은 최소 범위(읽기 전용)로 요청.
- **현지화**: 한국어/영어 우선. 시스템 시간대·달력 체계·주 시작 요일·12/24시간 표기 존중.
- **위젯 효율**: 타임라인 갱신을 시스템 예산 내로 제한, 불필요한 리로드 최소화.
- **안정성**: 권한 거부/캘린더 없음/네트워크 없음 등 모든 경계 상태에서 크래시 없이 graceful 처리.

---

## 9. 기술 스택 & 프로젝트 구조

### 9.1 프레임워크
- **SwiftUI**: 전 플랫폼 UI.
- **SwiftData**: 앱 설정(`AppSettings`) 저장 + CloudKit 동기화(선택적).
- **EventKit**: 이벤트 원본 **읽기 전용** 접근. `EventKitUI`는 사용하지 않는다(in-app 편집 없음).
- **WidgetKit + App Intents**: 구성 가능한 인터랙티브 위젯. `AppIntentConfiguration` + `WidgetConfigurationIntent`.
- **CloudKit**: 앱 설정 기기 간 동기화(SwiftData 통합).
- **UserNotifications**: 사용하지 않는다. EKAlarm은 시스템이 직접 처리.

### 9.2 타깃 구성 (목표 구조)
```
caldog/                      # Xcode 프로젝트 루트
├─ caldog/                   # 앱 타깃 (iOS/iPadOS/macOS 멀티플랫폼)
│  ├─ caldogApp.swift        # @main, ModelContainer 구성 (AppSettings만)
│  ├─ Models/                # SwiftData 보조 모델 (AppSettings만)
│  ├─ EventKit/              # EventKit 읽기 전용 게이트웨이/서비스 레이어
│  ├─ Features/              # 월 뷰, 위젯 구성 화면, 설정
│  └─ ...
├─ CaldogWidget/             # 위젯 익스텐션 타깃
│  ├─ CaldogWidgetBundle.swift
│  ├─ MonthWidget.swift      # WidgetKit 타임라인 + 뷰
│  └─ Intents/               # WidgetConfigurationIntent, AppEntity, EntityQuery
├─ CaldogKit/                # 앱·위젯 공유 로컬 Swift Package
│  ├─ EventStore.swift       # EKEventStore 읽기 전용 래퍼
│  ├─ MonthData.swift        # 월 그리드 계산 로직
│  └─ AppGroupState.swift    # App Group 공유 컨테이너 R/W
└─ docs/SPEC.md              # 본 문서
```

> 공유 코드는 **로컬 Swift Package**(`CaldogKit`)로 분리하고 앱/위젯 타깃이 의존한다(이슈 6 결정).

### 9.3 기존 자산 활용/변경
- `caldog/caldog/caldogApp.swift`: `ModelContainer` 스키마를 `AppSettings`만으로 교체.
- `caldog/caldog/Item.swift`: 삭제 후 `AppSettings` 모델로 대체.
- `caldog/caldog/ContentView.swift`: 컴패니언 앱 월 뷰 메인 화면으로 대체.
- `caldog/caldog/caldog.entitlements`: CloudKit 컨테이너 식별자 지정 + **App Group** 추가. **`aps-environment` 제거**(이슈 7).
- `caldog/caldog/Info.plist`: `NSCalendarsFullAccessUsageDescription` 추가. **`remote-notification` 백그라운드 모드 제거**(이슈 7). `NSRemindersFullAccessUsageDescription` 불필요.

---

## 10. 권한 · Entitlements · Info.plist 요구사항

### 10.1 Info.plist 사용 설명 (필수)
- `NSCalendarsFullAccessUsageDescription` — 캘린더 읽기 접근 사유 (필수).
- 미리알림, 쓰기 전용, 위치 관련 키는 필요하지 않다.

### 10.2 Entitlements / Capabilities
- **App Groups**: 앱 ↔ 위젯 월 탐색 상태 공유용 그룹 추가.
- **iCloud / CloudKit**: 기존 설정 활용, 컨테이너 식별자 지정 (`AppSettings` 동기화, 선택적).
- **Push/aps**: 사용하지 않음. `aps-environment` 엔타이틀먼트와 `remote-notification` 백그라운드 모드를 **제거**한다(이슈 7 결정).

---

## 11. 범위 밖 / 향후 과제

다음은 현재 명세 범위 밖이며 향후 검토 대상이다.

**위젯 중심 재포지셔닝에 따른 의도적 제외 항목**
- **앱 내 이벤트 생성/수정/삭제** — 애플 캘린더에 위임. `EventKitUI`/커스텀 편집기 불필요.
- **주 뷰 / 일 뷰 / 목록(아젠다) 뷰** — 풀 캘린더 앱 범위. 컴패니언 앱은 월 뷰만 제공.
- **검색** — 이벤트 전문 검색은 풀 앱 범위.
- **사용자 태그 / EventAnnotation** — 컴패니언 앱 범위 초과.
- **스마트 필터** — 컴패니언 앱 범위 초과.
- **보조 로컬 알림 (UserNotifications)** — EKAlarm 시스템 알림으로 충분.
- **미리알림(EKReminder) 통합** — 범위 밖. 미리알림 앱에 위임.

**일반적 향후 과제**
- Google/Outlook 등 **타사 캘린더 직접 연동**.
- 일정 **공유/협업·초대 응답** 고급 기능.
- AI 기반 일정 제안/자연어 일정 입력.
- 날씨/이동시간 등 외부 데이터 통합.
- Apple Watch 앱 / visionOS 지원.
- **잠금화면/액세서리 위젯** (accessoryRectangular/Circular/Inline) — v0.1 제외, 향후 버전(이슈 8).

---

## 12. 결정 완료 사항

v0.1~v0.3 과정에서 결정한 항목. v0.3에서 재포지셔닝에 따른 결정 사항 추가.

| # | 항목 | 결정 | 반영 |
|---|------|------|------|
| 1 | 미리알림 포함 범위 | **제외** — 컴패니언 앱 범위 밖. 미리알림 앱에 위임. | §4.1, §11 |
| 2 | 위젯 구성 깊이 | **표시 캘린더 + 주 시작 요일 + 강조 색 + 밀도** (App Intents 기반) | §5.2, §5.3 |
| 3 | 편집 UI | **앱 내 편집 없음** — 애플 캘린더에 전면 위임 (`calshow:`). EventKitUI 사용 안 함. | §4.3, §9.1 |
| 4 | `eventIdentifier` 안정성 | **해당 없음** — EventAnnotation/태그 구조 삭제로 식별자 안정성 문제 자체가 사라짐. | §3.2 |
| 5 | 고아 메타데이터 정리 | **해당 없음** — SwiftData 보조 모델이 `AppSettings` 하나뿐이므로 고아 레코드 개념 없음. | §3.2 |
| 6 | 공유 코드 패키징 | **로컬 Swift Package** (`CaldogKit`) | §9.2 |
| 7 | 푸시/백그라운드 엔타이틀먼트 | **제거** — aps-environment, remote-notification 삭제 | §4.4, §9.3, §10.2 |
| 8 | 잠금화면/액세서리 위젯 | **v0.1 제외** — 향후 버전 | §5.1, §11 |
| 9 | 앱 역할 재정의 (v0.3 신규) | **얇은 컴패니언** — 권한·월 뷰·위젯 구성만. CRUD 없음. 위젯이 핵심 제품. | §1, §4, §5 |
| 10 | SwiftData 모델 축소 (v0.3 신규) | **AppSettings 하나만** — Tag/EventAnnotation/SmartFilter/WidgetConfig/ViewState 전면 삭제. 위젯 구성은 App Intents로. | §3.2, §9.1 |
| 11 | 검색·태그·스마트필터 (v0.3 신규) | **제거** — 풀 캘린더 앱 범위. 컴패니언 앱과 맞지 않음. | §11 |

---

## 부록 A. 요구사항 ↔ 명세 추적표

| 원 요구사항 | 충족 섹션 |
|-------------|-----------|
| 앱 이름 caldog | 1.1 |
| SwiftUI + SwiftData 사용 | 2, 3.2, 9.1 |
| iCloud 멀티 디바이스 동기화 (앱 설정) | 6.2 (AppSettings=CloudKit) |
| 이벤트 읽기 / 한눈보기 | 4.2 |
| 편집 위임 (애플 캘린더) | 4.3 |
| 애플 캘린더 연동 (필수) | 2.1, 3.1, 4.2 |
| 월 캘린더 위젯 (이벤트 포함) | 5 |
| 인터랙티브 월 탐색 (prev/next/today) | 5.2.2 |
| 표시 캘린더 선택/필터 | 5.3.1 |
| 테마/밀도 옵션 | 5.3.2 |
| iOS/iPadOS/macOS 지원 | 1.3, 7, 9.2 |
| App Group (앱 ↔ 위젯 상태 공유) | 2.4, 5.2.2, 10.2 |
| 원격 푸시/보조 알림 없음 | 4.4, 10.2 |
