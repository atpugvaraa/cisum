//
// Animated Side Bar.swift
//  cisum
//
//  Created by Aarav Gupta on 29/03/24.
//

import SwiftUI

struct AnimatedSideBar<Content: View, MenuView: View, Background: View>: View {
    var rotatesWhenExpanded: Bool = true
    var disablesInteraction: Bool = false
    var sideMenuWidth: CGFloat = 200
    var cornerRadius: CGFloat = 25
    @Binding var showMenu: Bool
    @ViewBuilder var content: (UIEdgeInsets) -> Content
    @ViewBuilder var menuView: (UIEdgeInsets) -> MenuView
    @ViewBuilder var background: Background
    //View Properties
    @GestureState private var isDragged: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var lastOffsetX: CGFloat = 0
    @State private var progress: CGFloat = 0
    var body: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets ?? .zero
            HStack(spacing: 0) {
                GeometryReader { _ in
                    menuView(safeArea)
                }
                .frame(width: sideMenuWidth)
                //Clipping menu interaction beyond its width
                .contentShape(.rect)
                .scaleEffect(rotatesWhenExpanded ? 1 - (progress * 0.1) : 1, anchor: .trailing)
                .rotation3DEffect(
                    .init(degrees: rotatesWhenExpanded ? (Double(progress) * 15) : 0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )

                GeometryReader { _ in
                    content(safeArea)
                }
                .frame(width: size.width)
            }
            .frame(width: size.width + sideMenuWidth, height: size.height)
            .offset(x: -sideMenuWidth)
            .offset(x: offsetX)
            .contentShape(Rectangle())
            //MARK: Drag for Side Menu
            //Only use when done!!!
            .simultaneousGesture(dragGesture)
        }
        .background(background)
        .ignoresSafeArea()
        .onChange(of: showMenu) { value in
            withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                if value {
                    showSideBar()
                } else {
                    reset()
                }
            }
        }
        .gesture(dragGesture)
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragged) { _, out, _ in
                out = true
            }
            .onChanged { value in
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    guard value.startLocation.x > 15, isDragged else { return }

                    let translationX = isDragged ? max(min(value.translation.width + lastOffsetX, sideMenuWidth), 0) : 0
                    offsetX = translationX
                    dragProgress()
                }
            }
            .onEnded { value in
                guard value.startLocation.x > 15 else {return}
                
                withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                    let velocityX = value.predictedEndTranslation.width / 8
                    let total = velocityX + offsetX
                    
                    if total > (sideMenuWidth * 0.5) || progress >= 0.5 {
                        showSideBar()
                    } else {
                        reset()
                    }
                }
            }
    }
    
    //MARK: Show Side Bar
    func showSideBar() {
        offsetX = sideMenuWidth
        lastOffsetX = offsetX
        showMenu = true
        progress = 1 //complete the progress
    }
    
    //MARK: Reset to initial state
    func reset() {
        offsetX = 0
        lastOffsetX = 0
        showMenu = false
        progress = 0 // Reset the progress
    }
    
    //MARK: Calculate Drag Progress
    func dragProgress() {
        progress = max(min(offsetX / sideMenuWidth, 1), 0)
    }
}
