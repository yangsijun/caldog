import SwiftUI
import SwiftData
import CaldogKit

/// 컴패니언 앱 설정. 위젯 중심 제품이므로 앱 설정은 최소한으로 유지한다.
/// 위젯의 표시 캘린더·테마·밀도 등은 위젯을 길게 눌러 "위젯 편집"에서 구성한다(App Intents).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    var onChange: () -> Void = {}

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    Section("표시") {
                        Picker("주 시작 요일", selection: bind(\.firstWeekday, on: settings)) {
                            Text("일요일").tag(1)
                            Text("월요일").tag(2)
                        }
                        Toggle("24시간 표기", isOn: bind(\.uses24HourTime, on: settings))
                    }
                    Section {
                        Label("위젯 표시 캘린더·테마·밀도는 위젯을 길게 눌러 “위젯 편집”에서 설정하세요.",
                              systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("위젯")
                    }
                } else {
                    ProgressView()
                }
            }
            .formStyle(.grouped)
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        onChange()
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 360, minHeight: 320)
        }
    }

    private func bind<V>(_ keyPath: ReferenceWritableKeyPath<AppSettings, V>, on object: AppSettings) -> Binding<V> {
        Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}
