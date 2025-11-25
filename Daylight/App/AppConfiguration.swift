import Foundation

/// 控制是否启用模拟数据/远端 stub 的应用级配置。
struct AppConfiguration {
    let useMockData: Bool
    let useRemoteStub: Bool

    static func load(processInfo: ProcessInfo = .processInfo) -> AppConfiguration {
        func isOn(_ raw: String?) -> Bool {
            guard let raw else { return false }
            return ["1", "true", "yes", "on"].contains(raw.lowercased())
        }

        func flag(_ key: String) -> Bool {
            isOn(processInfo.environment[key]) || processInfo.arguments.contains("-\(key)")
        }

        #if DEBUG
        let mockEnabled = flag("USE_MOCK_DATA") || flag("useMockData")
        let remoteStub = flag("USE_REMOTE_STUB") || mockEnabled
        #else
        let mockEnabled = false
        let remoteStub = false
        #endif

        return AppConfiguration(
            useMockData: mockEnabled,
            useRemoteStub: remoteStub
        )
    }
}
