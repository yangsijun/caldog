#if os(iOS)
import SwiftUI
import EventKit
import EventKitUI

/// 애플 캘린더와 동일한 네이티브 일정 상세 화면(EventKitUI `EKEventViewController`)을
/// 인앱 시트로 표시한다. 특정 일정을 가리키는 공개 URL 스킴이 없어, 읽기 전용 컴패니언이
/// 그 일정을 보여줄 수 있는 가장 가까운 방법이다. 화면의 "편집"으로 애플 캘린더 편집 흐름에
/// 연결된다.
struct EventDetailView: UIViewControllerRepresentable {
    let event: EKEvent
    var onClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onClose: onClose) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let detail = EKEventViewController()
        detail.event = event
        detail.allowsEditing = true
        detail.allowsCalendarPreview = true
        detail.delegate = context.coordinator
        detail.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        return UINavigationController(rootViewController: detail)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, EKEventViewDelegate {
        let onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }

        @objc func close() { onClose() }

        func eventViewController(_ controller: EKEventViewController,
                                 didCompleteWith action: EKEventViewAction) {
            // 삭제/응답 등으로 상세가 완료되면 닫는다.
            onClose()
        }
    }
}
#endif
