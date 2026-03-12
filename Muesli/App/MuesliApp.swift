import SwiftUI

@main
struct MuesliApp: App {
    @StateObject private var model: MuesliAppModel

    init() {
        let model = MuesliAppModel()
        _model = StateObject(wrappedValue: model)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra("Muesli", systemImage: model.activeSession == nil ? "waveform.circle" : "record.circle.fill") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("History", id: "history") {
            HistoryWindowView(model: model)
        }
        .defaultSize(width: 680, height: 420)

        Settings {
            SettingsView(model: model)
        }
    }
}
