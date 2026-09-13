import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public var isEnabled: Bool = false
    
    public init() {
        checkStatus()
    }
    
    public func checkStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
    }
    
    public func setEnabled(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("LaunchAtLogin error: \(error.localizedDescription)")
        }
        checkStatus()
    }
}
