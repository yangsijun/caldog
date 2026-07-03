import SwiftUI
import CaldogKit

/// 선택된 날짜의 일정 목록(읽기 전용 글랜스).
///
/// 자체 스크롤. 위로 스크롤하면 월 그리드가 접히고(빈 날도 가능), 맨 위에서 아래로
/// 당기면 펼쳐진다. 그래버(상위 뷰)로도 토글 가능.
/// 행을 탭하면 애플 캘린더로 이동한다(생성/편집/삭제는 애플 캘린더에 위임).
struct DayEventsView: View {
    @Bindable var store: CalendarStore
    /// 월 그리드 축소 상태(상위 뷰 소유). 스크롤로도 토글한다.
    @Binding var collapsed: Bool
    /// 일정(또는 해당 날짜)을 애플 캘린더에서 열기.
    var onOpen: (CalendarEvent) -> Void

    private var events: [CalendarEvent] {
        store.events(on: store.selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerTitle)
                .font(.subheadline).bold()
                .padding(.horizontal)
                .padding(.bottom, 4)

            if events.isEmpty {
                // 빈 날도 스크롤로 접을 수 있도록 ScrollView로 감싼다.
                ScrollView {
                    ContentUnavailableView("일정 없음", systemImage: "calendar.day.timeline.left",
                                           description: Text("이 날짜에는 일정이 없습니다."))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                }
                .frame(maxHeight: .infinity)
                .modifier(CollapseOnScroll(collapsed: $collapsed))
            } else {
                List {
                    ForEach(events) { event in
                        Button {
                            onOpen(event)
                        } label: {
                            EventRow(event: event, calendar: store.calendar)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .modifier(CollapseOnScroll(collapsed: $collapsed))
            }
        }
    }

    private var headerTitle: String {
        let df = DateFormatter()
        df.calendar = store.calendar
        df.locale = store.calendar.locale ?? .current
        df.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return df.string(from: store.selectedDate)
    }
}

/// 스크롤로 월 그리드 접기/펼치기.
///
/// 스크롤을 위로 시작하는 즉시(offset이 top을 살짝 벗어나면) 접어, 목록이 내부에서
/// 한참 스크롤된 뒤에야 접히는 어색함을 없앤다(애플 대형 타이틀 접힘과 유사).
/// 펼침은 맨 위에서 아래로 당길 때(음수 오버스크롤 < -30)만 트리거해
/// "접힘→목록 높이 증가→오프셋 0 복귀→재펼침" 진동을 차단한다.
/// 빈/짧은 목록도 끌어서 접을 수 있도록 항상 바운스를 켠다.
private struct CollapseOnScroll: ViewModifier {
    @Binding var collapsed: Bool

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, y in
                if y > 6, !collapsed {
                    withAnimation(.easeInOut(duration: 0.22)) { collapsed = true }
                } else if y < -30, collapsed {
                    withAnimation(.easeInOut(duration: 0.22)) { collapsed = false }
                }
            }
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.isEmpty ? "(제목 없음)" : event.title)
                    .font(.body)
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if event.hasRecurrence {
                Image(systemName: "repeat").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "arrow.up.forward.app")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var timeText: String {
        if event.isAllDay { return "종일" }
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = calendar.locale ?? .current
        df.timeStyle = .short
        df.dateStyle = .none
        return "\(df.string(from: event.start)) – \(df.string(from: event.end))"
    }
}
