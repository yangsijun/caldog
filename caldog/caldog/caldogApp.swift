//
//  caldogApp.swift
//  caldog
//

import SwiftUI
import SwiftData
import CaldogKit

@main
struct caldogApp: App {
    /// 일정 원본 게이트웨이(EventKit). 앱 전역에서 환경으로 주입.
    @State private var gateway: EventStoreGateway = EventKitGateway()

    /// 보조 메타데이터(설정/태그/필터 등) 저장소.
    /// NOTE: iCloud(CloudKit) 동기화는 iCloud capability 프로비저닝 후
    /// `cloudKitDatabase: .automatic`으로 전환한다. 현재는 로컬 저장만.
    let sharedModelContainer: ModelContainer = {
        let schema = Schema(CaldogSchema.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.eventStore, gateway)
        }
        .modelContainer(sharedModelContainer)
    }
}
