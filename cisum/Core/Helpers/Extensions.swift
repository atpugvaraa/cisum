//
//  Extensions.swift
//  cisum
//
//  Created by Aarav Gupta on 08/04/24.
//

import Foundation
import SwiftUI
import UIKit

extension PreviewProvider {
    static var dev: DevPreview {
        return DevPreview.shared
    }
}

class DevPreview {
    static let shared = DevPreview()
    
    let user = User(id: NSUUID().uuidString, email: "max@gmail.com", firstname: "Max Verstappen", username: "maxverstappen")
}

class VolumeObserverManager {
    private var observer: NSObjectProtocol?

    init() {
        // Initialize the observer
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleVolumeChange()
        }
    }

    // Method to handle volume changes
    private func handleVolumeChange() {
        // Handle the volume change as needed
        // For example, you could update the current volume level in your `VolumeSlider` here
    }

    // Method to remove the observer
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension UIApplication {
  func rootController() -> UIViewController {
    guard let window = connectedScenes.first as? UIWindowScene else {return .init()}
    guard let viewcontroller = window.windows.last?.rootViewController else {return .init()}

    return viewcontroller
  }
}

extension Double {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? ""
    }
}

extension BinaryFloatingPoint {
    func asTimeString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = style
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self)) ?? ""
    }
}

extension View {
  var deviceCornerRadius: CGFloat {
    let key = "_displayCornerRadius"
    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
      if let cornerRadius = screen.value(forKey: key) as? CGFloat {
        return cornerRadius
      }

      return 0
    }

    return 0
  }
}

//MARK: TOP RIGHT BUTTON
extension View {
    func navigationBarLargeTitleItems<TrailingItems: View>(visible: Bool, trailingItems: @escaping () -> TrailingItems) -> some View {
        self.background(NavigationBarLargeTitleItems(visible: visible, trailingItems: trailingItems))
    }
}

fileprivate struct NavigationBarLargeTitleItems<TrailingItems: View>: UIViewControllerRepresentable {
    typealias UIViewControllerType = Wrapper

    private let visible: Bool
    private let trailingItems: TrailingItems

    init(visible: Bool, trailingItems: @escaping () -> TrailingItems) {
        self.visible = visible
        self.trailingItems = trailingItems()
    }

    func makeUIViewController(context: Context) -> Wrapper {
        Wrapper(barItems: trailingItems)
    }

    func updateUIViewController(_ uiViewController: Wrapper, context: Context) {
        uiViewController.updatesBarItemsVisibility(isHidden: !visible)
    }

    class Wrapper: UIViewController {
        private let barItems: TrailingItems?
        private var barItemsController: UIHostingController<TrailingItems>?

        init(barItems: TrailingItems) {
            self.barItems = barItems
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            self.barItems = nil
            super.init(coder: coder)
        }

        override func viewWillAppear(_ animated: Bool) {
            guard let barItems = self.barItems, barItemsController == nil else { return }
            guard let navigationBar = self.navigationController?.navigationBar else { return }
            guard let UINavigationBarLargeTitleView = NSClassFromString("_UINavigationBarLargeTitleView") else { return }

            navigationBar.subviews.forEach { subview in
                if subview.isKind(of: UINavigationBarLargeTitleView.self) {
                    let controller = UIHostingController<TrailingItems>(rootView: barItems)
                    controller.view.translatesAutoresizingMaskIntoConstraints = false
                    controller.view.backgroundColor = .clear
                    subview.addSubview(controller.view)

                    NSLayoutConstraint.activate([
                        controller.view.bottomAnchor.constraint(
                            equalTo: subview.bottomAnchor,
                            constant: -15
                        ),
                        controller.view.trailingAnchor.constraint(
                            equalTo: subview.trailingAnchor,
                            constant: -view.directionalLayoutMargins.trailing
                        )
                    ])
                    self.barItemsController = controller
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
//            self.configureBarItemsTransparency(alpha: .zero)
//            self.updatesBarItemsVisibility(isHidden: true)
        }

        func updatesBarItemsVisibility(isHidden: Bool) {
//            self.configureBarItemsTransparency(alpha: isHidden ? 1.0 : .zero)
            UIView.animate(withDuration: isHidden ? 0.2 : 0.1) {
                self.barItemsController?.view.alpha = isHidden ? .zero : 1
            }
        }

        private func configureBarItemsTransparency(alpha: CGFloat) {
            guard let navigationBar = self.navigationController?.navigationBar else {
                return
            }

            guard let UINavigationBarLargeTitleView = NSClassFromString("_UINavigationBarLargeTitleView") else {
                return
            }

            navigationBar.subviews.forEach {
                subview in
                if subview.isKind(of: UINavigationBarLargeTitleView.self) {
                    subview.alpha = alpha
                }
            }
        }
    }
}
