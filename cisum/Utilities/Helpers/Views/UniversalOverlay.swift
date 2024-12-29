//
//  UniversalOverlay.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

extension View {
    @ViewBuilder
    func universalOverlay<Content: View>(
        animation: Animation = .easeInOut, // Adjust to liking
        show: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(UniversalOverlayModifier(animation: animation, show: show, viewContent: content))
    }
}

class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view
        else { return nil }
        
        // Compatibility layer for hit testing
        for subView in rootView.subviews.reversed() {
            let pointInSubView = subView.convert(point, from: rootView)
            if subView.hitTest(pointInSubView, with: event) == subView {
                return hitView
            }
        }
        return hitView == rootView ? nil : hitView
    }
}

struct RootView<Content: View>: View {
    var content: Content
    @StateObject private var properties = UniversalOverlayProperties()
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .environmentObject(properties)
            .onAppear {
                if let windowScene = (UIApplication.shared.connectedScenes.first as? UIWindowScene), properties.window == nil {
                    let window = PassThroughWindow(windowScene: windowScene)
                    window.isHidden = false
                    window.isUserInteractionEnabled = true
                    let rootViewController = UIHostingController(
                        rootView: UniversalOverlayViews()
                            .environmentObject(properties)
                    )
                    rootViewController.view.backgroundColor = .clear
                    window.rootViewController = rootViewController
                    
                    properties.window = window
                }
            }
    }
}

class UniversalOverlayProperties: ObservableObject {
    @Published var window: UIWindow?
    @Published var views: [OverlayView] = []
    
    struct OverlayView: Identifiable {
        var id: String = UUID().uuidString
        var view: AnyView
    }
}

fileprivate struct UniversalOverlayModifier<ViewContent: View>: ViewModifier {
    var animation: Animation
    @Binding var show: Bool
    @ViewBuilder var viewContent: ViewContent
    
    @EnvironmentObject private var properties: UniversalOverlayProperties
    @State private var viewID: String?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: show) { newValue in
                if newValue {
                    addView()
                } else {
                    removeView()
                }
            }
    }
    
    private func addView() {
        if properties.window != nil && viewID == nil {
            viewID = UUID().uuidString
            guard let viewID else { return }
            
            withAnimation(animation) {
                properties.views.append(.init(id: viewID, view: .init(viewContent)))
            }
        }
    }
    
    private func removeView() {
        if let viewID {
            withAnimation(animation) {
                properties.views.removeAll(where: { $0.id == viewID })
            }
            
            self.viewID = nil
        }
    }
}

fileprivate struct UniversalOverlayViews: View {
    @EnvironmentObject private var properties: UniversalOverlayProperties
    
    var body: some View {
        ZStack {
            ForEach(properties.views) {
                $0.view
            }
        }
    }
}
