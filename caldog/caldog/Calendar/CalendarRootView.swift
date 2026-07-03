import SwiftUI
import CaldogKit

/// 위젯 중심 컴패니언의 메인 화면: 글랜스용 월 뷰 + 선택일 일정 + 애플 캘린더로 점프.
struct CalendarRootView: View {
    @Bindable var store: CalendarStore
    @Environment(\.openURL) private var openURL
    @State private var showSettings = false
    /// 월 그리드를 선택 주 한 줄로 축소(그래버 드래그/탭으로 토글).
    @State private var monthCollapsed = false
    /// 인앱 네이티브 상세로 표시 중인 일정(iOS).
    @State private var detailEvent: CalendarEvent?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                MonthCalendarView(store: store, collapsed: monthCollapsed)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                    .gesture(monthSwipe)
                grabber
                Divider()
                DayEventsView(store: store, collapsed: $monthCollapsed) { event in
                    handleEventTap(event)
                }
                .frame(maxHeight: .infinity)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("오늘") { store.goToToday() }
                }
                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openInAppleCalendar(date: store.selectedDate)
                    } label: {
                        Label("애플 캘린더에서 열기", systemImage: "calendar")
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("설정", systemImage: "gearshape")
                    }
                }
            }
            // 위젯 딥링크로 특정 날짜에 진입하면 월을 접어 일정 목록을 넓게 보여준다.
            .onChange(of: store.deepLinkArrivals) {
                withAnimation(.easeInOut(duration: 0.28)) { monthCollapsed = true }
            }
            // 위젯에서 콜드 런치된 경우(뷰가 뜨기 전 딥링크 처리됨)도 접힌 상태로 시작.
            .onAppear {
                if store.deepLinkArrivals > 0 { monthCollapsed = true }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView { store.reload() }
            }
            #if os(iOS)
            .sheet(item: $detailEvent) { event in
                if let ekEvent = store.ekEvent(for: event) {
                    EventDetailView(event: ekEvent) { detailEvent = nil }
                        .ignoresSafeArea()
                }
            }
            #endif
        }
    }

    /// 일정 탭: iOS는 애플 네이티브 일정 상세를 인앱 시트로 표시하고, 원본을 못 찾으면
    /// 해당 날짜로 점프한다. macOS는 상세 UI(EventKitUI)가 없어 동작하지 않는다.
    private func handleEventTap(_ event: CalendarEvent) {
        #if os(iOS)
        if store.ekEvent(for: event) != nil {
            detailEvent = event
        } else {
            openInAppleCalendar(date: event.start)
        }
        #endif
    }

    /// 월/목록 사이 그래버: 위로 끌면 한 주로 접고 아래로 끌면 펼친다. 탭으로도 토글.
    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onEnded { value in
                        if value.translation.height < -12 {
                            withAnimation(.easeInOut(duration: 0.28)) { monthCollapsed = true }
                        } else if value.translation.height > 12 {
                            withAnimation(.easeInOut(duration: 0.28)) { monthCollapsed = false }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.28)) { monthCollapsed.toggle() }
            }
            .accessibilityLabel(monthCollapsed ? "월 전체 보기" : "주간으로 접기")
            .accessibilityAddTraits(.isButton)
    }

    /// 일정 생성/편집은 애플 캘린더에 위임한다(SPEC §4.3).
    private func openInAppleCalendar(date: Date) {
        if let url = store.appleCalendarURL(for: date) { openURL(url) }
    }

    private var monthHeader: some View {
        HStack {
            Button { withAnimation { store.goToMonth(offset: -1) } } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            Spacer()
            Text(store.monthTitle).font(.title3.bold())
            Spacer()
            Button { withAnimation { store.goToMonth(offset: 1) } } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    /// 좌우 스와이프로 달 이동(애플 캘린더 방식).
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -50 {
                    withAnimation { store.goToMonth(offset: 1) }
                } else if value.translation.width > 50 {
                    withAnimation { store.goToMonth(offset: -1) }
                }
            }
    }
}

#Preview {
    let store = CalendarStore(gateway: MockEventStore(events: SampleData.events))
    store.reload()
    return CalendarRootView(store: store)
}
