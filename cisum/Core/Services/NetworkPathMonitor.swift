import Foundation
import Network

@Observable
@MainActor
final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    enum Interface: String {
        case wifi
        case cellular
        case wiredEthernet
        case loopback
        case other
        case unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "cisum.network.path.monitor")

    var isExpensive: Bool = false
    var isConstrained: Bool = false
    var interface: Interface = .unknown

    init() {
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

    var profileName: String {
        "\(interface.rawValue)-\(isConstrained ? "constrained" : "normal")-\(isExpensive ? "expensive" : "standard")"
    }
}
