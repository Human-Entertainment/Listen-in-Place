import SwiftUI
import NIO

private struct ThreadPoolEnvironmentKey: EnvironmentKey {
    static let defaultValue: NIOThreadPool = NIOThreadPool(numberOfThreads: 1)
}

extension EnvironmentValues {
    var threadPool: NIOThreadPool {
        get { self[ThreadPoolEnvironmentKey.self] }
        set { self[ThreadPoolEnvironmentKey.self] = newValue }
    }
}
