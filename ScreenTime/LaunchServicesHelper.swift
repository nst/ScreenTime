import Foundation
import ServiceManagement

class LaunchServicesHelper {

    private let service = SMAppService.mainApp

    var applicationIsInStartUpItems: Bool {
        return service.status == .enabled
    }

    func toggleLaunchAtStartup() {
        do {
            if applicationIsInStartUpItems {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Failed to toggle login item: \(error)")
        }
    }
}
