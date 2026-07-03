import SwiftUI
import CaldogKit

/// 최초 권한 요청 안내 화면.
struct PermissionGateView: View {
    let store: CalendarStore
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("caldog가 캘린더에 접근합니다")
                .font(.title2).bold()
            Text("일정을 위젯과 앱에서 확인하려면 캘린더 접근 권한이 필요합니다. 일정은 Apple 캘린더에 저장되고 iCloud로 동기화되며, 추가·수정은 Apple 캘린더에서 이루어집니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                requesting = true
                Task {
                    await store.requestAccess()
                    requesting = false
                }
            } label: {
                Text(requesting ? "요청 중…" : "캘린더 접근 허용")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(requesting)
        }
        .padding(40)
    }
}

/// 권한이 거부된 경우 안내.
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("캘린더 접근이 꺼져 있습니다")
                .font(.title3).bold()
            Text("설정 앱에서 caldog의 캘린더 접근을 허용해 주세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #if os(iOS)
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            #endif
        }
        .padding(40)
    }
}
