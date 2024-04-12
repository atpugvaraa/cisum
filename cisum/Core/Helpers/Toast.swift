//
//  Toast.swift
//  cisum
//
//  Created by Aarav Gupta on 11/04/24.
//

import SwiftUI

struct RootView<Content: View>: View {
  @ViewBuilder var content: Content
  //View Properties
  @State private var overlayWindow: UIWindow?
    var body: some View {
        content
        .onAppear {
          if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, overlayWindow == nil {
            let window = PassthroughWindow(windowScene: windowScene)
            window.backgroundColor = .clear
            //View Controller
            let rootController = UIHostingController(rootView: ToastGroup())
            rootController.view.frame = windowScene.keyWindow?.frame ?? .zero
            rootController.view.backgroundColor = .clear
            window.rootViewController = rootController
            window.isHidden = false
            window.isUserInteractionEnabled = true
            window.tag = 1009

            overlayWindow = window
          }
        }
    }
}

fileprivate class PassthroughWindow: UIWindow {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let view = super.hitTest(point, with: event) else {return nil}

    return rootViewController?.view == view ? nil : view
  }
}

class Toast: Observable {
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  static let shared = Toast()
  fileprivate var toasts: [ToastItem] = []

  func present(title: String, tint: Color = Color.accentColor, isUserInteractionEnabled: Bool = false, timing: ToastTime = .medium) {
    withAnimation(.snappy) {
      toasts.append(.init(title: title, tint: tint, isUserInteractionEnabled: false, timing: timing))
    }
  }
}

struct ToastItem: Identifiable {
  let id: UUID = .init()
  //Custom Properties
  var title: String
  var tint: Color
  var isUserInteractionEnabled: Bool
  //Timing
  var timing: ToastTime = .medium
}

enum ToastTime: CGFloat {
  case short = 1.0
  case medium = 2.0
  case long = 3.0
}

fileprivate struct ToastGroup: View {
  var model = Toast.shared
  var body: some View {
    GeometryReader {
      let size = $0.size
      let safeArea = $0.safeAreaInsets

      ZStack {
        ForEach(model.toasts) {toast in
          ToastView(size: size, item: toast)
            .scaleEffect(scale(toast))
            .offset(y: offsetY(toast))
            .zIndex(Double(model.toasts.firstIndex(where: { $0.id == toast.id }) ?? 0))
        }
      }
      .padding(.bottom, safeArea.top == .zero ? 15 : 10)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
  }

  func offsetY(_ item: ToastItem) -> CGFloat {
    let index = CGFloat(model.toasts.firstIndex(where: {$0.id == item.id}) ?? 0)
    let totalCount = CGFloat(model.toasts.count) - 1
    return (totalCount - index) >= 2 ? -20 : ((totalCount - index) * -10)
  }

  func scale(_ item: ToastItem) -> CGFloat {
    let index = CGFloat(model.toasts.firstIndex(where: {$0.id == item.id}) ?? 0)
    let totalCount = CGFloat(model.toasts.count) - 1
    return 1.0 - ((totalCount - index) >= 2 ? 0.2 : ((totalCount - index) * 0.1))
  }
}

fileprivate struct ToastView: View {
  var size: CGSize
  var item: ToastItem
  //View Properties
  @State private var delayTask: DispatchWorkItem?

  var body: some View {
    HStack(spacing: 0) {
      Text(item.title)
    }
    .foregroundStyle(item.tint)
    .padding(.horizontal, 15)
    .padding(.vertical, 8)
    .background(.bg, in: .capsule)
    .contentShape(.capsule)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onEnded({ value in
          let endY = value.translation.height
          let velocityY = value.velocity.height

          if (endY + velocityY) > 100 {
            removeToast()
          }
        })
    )
    .onAppear {
      guard delayTask == nil else {return}
      delayTask = .init(block: {
        removeToast()
      })

      if let delayTask {
        DispatchQueue.main.asyncAfter(deadline: .now() + item.timing.rawValue, execute: delayTask)
      }
    }
    //Size limit
    .frame(maxWidth: size.width)
    .transition(.offset(y: 150))
  }

  func removeToast() {
    if let delayTask {
      delayTask.cancel()
    }
    withAnimation(.snappy) {
      Toast.shared.toasts.removeAll(where: {$0.id == item.id})
    }
  }
}
