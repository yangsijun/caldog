//
//  ContentView.swift
//  caldog
//

import SwiftUI
import SwiftData
import EventKit
import WidgetKit
import CaldogKit

struct ContentView: View {
    @Environment(\.eventStore) private var gateway
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [AppSettings]
    @State private var store: CalendarStore?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Group {
            if let store {
                content(for: store)
            } else {
                ProgressView()
            }
        }
        .task {
            ensureSettings()
            if store == nil {
                let newStore = CalendarStore(gateway: gateway)
                if let settings { newStore.applyFirstWeekday(settings.firstWeekday) }
                newStore.reload()
                store = newStore
            }
        }
        .onChange(of: settings?.firstWeekday) { _, newValue in
            if let newValue { store?.applyFirstWeekday(newValue) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store?.refreshAuthorization()
                store?.reload()
                // 위젯 타임라인은 자정에만 갱신되므로, 앱 진입을 위젯 최신화 기회로 쓴다
                // (위젯 중심 앱 — 낮 동안의 일정 변경이 자정까지 위젯에 안 보이는 공백 보완).
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        // 앱 실행 중 애플 캘린더 DB가 바뀌면(다른 앱/동기화 포함) 화면과 위젯을 함께 갱신.
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            store?.reload()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    /// 최초 실행 시 기본 설정 레코드를 1개 보장.
    private func ensureSettings() {
        guard settingsList.isEmpty else { return }
        let settings = AppSettings()
        settings.createdAt = Date()
        context.insert(settings)
    }

    /// caldog://date/yyyy-MM-dd 형태의 위젯 딥링크 처리.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "caldog", url.host == "date" else { return }
        let dateString = url.lastPathComponent
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy-MM-dd"
        if let date = df.date(from: dateString) {
            store?.navigate(to: date)
        }
    }

    @ViewBuilder
    private func content(for store: CalendarStore) -> some View {
        if store.authorization.canRead {
            CalendarRootView(store: store)
        } else if store.authorization == .notDetermined {
            PermissionGateView(store: store)
        } else {
            PermissionDeniedView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
