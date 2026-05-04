import Foundation
import Network

@Observable
@MainActor
public final class NetworkPathMonitor {
    public static let shared = NetworkPathMonitor()

    public enum Interface: String {
        case wifi
        case cellular
        case wiredEthernet
        case loopback
        case other
        case unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "cisum.network.path.monitor")

    public var isExpensive: Bool = false
    public var isConstrained: Bool = false
    public var interface: Interface = .unknown

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                if path.usesInterfaceType(.wifi) {
                    self.interface = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.interface = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.interface = .wiredEthernet
                } else if path.usesInterfaceType(.loopback) {
                    self.interface = .loopback
                } else if path.usesInterfaceType(.other) {
                    self.interface = .other
                } else {
                    self.interface = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    public var profileName: String {
        "\(interface.rawValue)-\(isConstrained ? "constrained" : "normal")-\(isExpensive ? "expensive" : "standard")"
    }
}
