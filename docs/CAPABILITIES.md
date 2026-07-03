# caldog Capability 연결 가이드

헤드리스 빌드(`CODE_SIGNING_ALLOWED=NO`)로는 검증할 수 없는, **Xcode UI에서 직접 해야 하는** capability·서명 설정을 정리한다. 코드/엔티티먼트 파일은 이미 준비돼 있으며, 아래는 프로비저닝과 빌드 설정 연결 단계다.

대상 프로젝트: `caldog/caldog.xcodeproj` · 앱 타깃 `caldog` · 위젯 타깃 `CaldogWidget`
Apple Developer Team: `9ZMW52M7L5` · Bundle ID: `dev.sijun.caldog`

---

## 0. 사전 준비
- Xcode에서 `caldog/caldog.xcodeproj` 열기.
- 각 타깃 → **Signing & Capabilities** 탭에서 **Automatically manage signing** 켜고 Team 선택.

---

## 1. 캘린더/미리알림 (이미 동작 — 추가 설정 불필요)
- EventKit 접근은 **Info.plist 사용 설명**만 있으면 된다. 이미 추가됨:
  - `NSCalendarsFullAccessUsageDescription`
  - `NSRemindersFullAccessUsageDescription`
- 첫 실행 시 권한 다이얼로그가 뜬다. (위젯 타깃 Info.plist에도 동일 사용 설명 포함됨)
- macOS는 App Sandbox가 켜져 있으므로 캘린더 접근 시 시스템이 자동 처리한다(사용 설명 기반).
- 캘린더는 **읽기 전용**으로만 사용한다(편집은 애플 캘린더에 위임). 재포지셔닝으로 미리알림/보조 로컬 알림 기능은 제거됨 — `NSRemindersFullAccessUsageDescription`는 미사용이며 추후 정리 가능.

---

## 2. App Group (위젯 월 이동 상태 공유) — **위젯 핵심 기능에 필요**
> 위젯의 일정 표시 자체는 EventKit 직접 읽기로 App Group 없이도 되지만,
> **위젯 내 이전/다음 달 이동(‹ › 버튼)** 은 인터랙티브 AppIntent가 갱신한 `monthOffset`을
> 타임라인 공급자가 다시 읽어야 한다. 이 공유 저장소가 `UserDefaults(suiteName: "group.dev.sijun.caldog")`이므로
> **월 이동이 안정적으로 동작하려면 App Group capability 활성화가 필요**하다.

엔티티먼트 파일은 양쪽 타깃 모두 준비됨:
- 앱: `caldog/caldog/caldog.entitlements` (그룹 포함)
- 위젯: `caldog/CaldogWidget/CaldogWidget.entitlements` (그룹 포함, 이번에 추가)

연결 절차:

1. **앱 타깃** → Signing & Capabilities → **+ Capability → App Groups** → `group.dev.sijun.caldog` 체크(없으면 **+** 로 생성).
2. **CaldogWidget 타깃**에도 동일하게 App Groups 추가 + 같은 그룹 체크.
3. 두 타깃의 빌드 설정 `CODE_SIGN_ENTITLEMENTS`를 각 엔티티먼트 파일로 연결(보통 capability 추가 시 자동). 수동/CLI:

```bash
cd /Users/sijun/coding/caldog
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("caldog/caldog.xcodeproj")
{ "caldog" => "caldog/caldog.entitlements",
  "CaldogWidget" => "CaldogWidget/CaldogWidget.entitlements" }.each do |name, ent|
  t = p.targets.find { |x| x.name == name }
  t.build_configurations.each { |c| c.build_settings["CODE_SIGN_ENTITLEMENTS"] = ent }
end
p.save
'
```

> 참고: 헤드리스 빌드를 깨지지 않게 두려고 `CODE_SIGN_ENTITLEMENTS`는 **아직 미연결** 상태다.
> App Group 미연결 시에도 위젯은 빌드/표시되지만, 월 이동 버튼은 위젯 익스텐션 프로세스 내에서만
> 동작이 보장된다(정식 동작 = App Group 활성화).

---

## 3. iCloud / CloudKit (보조 메타데이터 동기화)
보조 데이터(앱 설정 `AppSettings` — 주 시작 요일/24시간 표기)를 기기 간 동기화하려면 CloudKit을 켠다. (일정 자체는 iCloud 캘린더가 동기화하므로 이 단계와 무관. 재포지셔닝으로 태그/필터 모델은 제거됨)

### 3-1. Capability 추가
1. **앱 타깃** → Signing & Capabilities → **+ Capability → iCloud**.
2. **CloudKit** 체크.
3. 컨테이너에서 `iCloud.dev.sijun.caldog` 선택(없으면 **+** 로 생성). 엔티티먼트에 이미 이 식별자가 들어 있다.

### 3-2. 엔티티먼트 파일 연결
Xcode가 capability를 추가하면 보통 자동으로 `CODE_SIGN_ENTITLEMENTS`를 설정한다. 안 되면 수동:
- 앱 타깃 → Build Settings → **Code Signing Entitlements** = `caldog/caldog.entitlements`

또는 CLI로:
```bash
cd /Users/sijun/coding/caldog
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("caldog/caldog.xcodeproj")
t = p.targets.find { |x| x.name == "caldog" }
t.build_configurations.each { |c| c.build_settings["CODE_SIGN_ENTITLEMENTS"] = "caldog/caldog.entitlements" }
p.save
'
```

### 3-3. 코드에서 CloudKit 켜기
`caldog/caldog/caldogApp.swift`의 ModelConfiguration를 변경:
```swift
// 변경 전 (로컬 전용)
cloudKitDatabase: .none
// 변경 후 (CloudKit private DB 동기화)
cloudKitDatabase: .automatic
```
> 주의: `.automatic`은 iCloud capability + 컨테이너 프로비저닝이 완료돼야 런타임 오류가 나지 않는다. 반드시 3-1/3-2 이후에 전환할 것.

---

## 4. 빌드/실행 검증
```bash
# 시뮬레이터/기기 실행 전, 서명 포함 빌드(자동 서명 사용)
cd /Users/sijun/coding/caldog/caldog
xcodebuild -scheme caldog -destination 'platform=iOS Simulator,name=iPhone 16' build
```
실기기 실행 체크리스트:
1. 앱 첫 실행 → 캘린더 권한 다이얼로그 허용.
2. 월 캘린더(글랜스) 표시 + 선택일 일정 목록 확인.
3. 일정/날짜 탭 또는 툴바 **캘린더** 버튼 → **애플 캘린더**가 해당 날짜로 열림(`calshow:`). 생성/편집/삭제는 애플 캘린더에 위임.
4. 홈 화면에 **월 캘린더 위젯**(특히 4×4 Large) 추가 → 길게 눌러 ‘편집’ → **표시 캘린더 선택 / 주 시작 요일 / 강조 색 / 정보 밀도(보통·촘촘)** 변경.
5. 위젯의 **‹ / ›** 버튼으로 이전/다음 달 이동, **오늘** 버튼으로 복귀(App Group 활성화 필요).
6. Large/특대 위젯 셀에 **연속 일정 바**(제목)가 보이는지 확인(작은/중간은 점). 정보 밀도 ‘촘촘’ 시 레인 수가 줄어드는지 확인.
7. 위젯 날짜 탭 → 앱이 해당 날짜로 이동(딥링크 `caldog://date/...`).
8. (CloudKit 켠 경우) 두 기기에서 앱 설정 동기화 확인.

---

## 5. 현재 헤드리스로 검증된 항목 (참고)
- `swift test` (CaldogKit): 48개 통과.
- `xcodebuild` BUILD SUCCEEDED: iOS·macOS × (앱, 앱+위젯) — 모두 `CODE_SIGNING_ALLOWED=NO`.
- 위젯 임베드 확인: `caldog.app/PlugIns/CaldogWidget.appex`.
