import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var message = ""

    init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            message = ""
            refresh()
        } catch {
            message = "设置开机启动失败：\(error.localizedDescription)"
            FileLogger.shared.error(.app, "login_item_update_failed enabled=\(enabled) type=\(String(describing: type(of: error)))")
        }
    }

    func registerByDefaultIfNeeded(settings: AppSettings) {
        guard Bundle.main.bundlePath.hasSuffix(".app"), !settings.didAttemptLoginRegistration else { return }
        settings.didAttemptLoginRegistration = true
        setEnabled(true)
    }
}
