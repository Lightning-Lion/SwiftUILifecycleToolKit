//
//  SwiftUILifecycleToolKit.swift
//
//
//  Created by 闪电狮 on 2025/1/10.
//

import SwiftUI

// MARK: 提供onLoad扩展，避免难以调试的Bug（意外触发了多次加载）
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
extension View {
    @ViewBuilder
    public func onLoad(_ action:@escaping () -> ()) -> some View {
        self
            .modifier(OnLoad(action: action))
    }
}

@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
fileprivate
struct OnLoad: ViewModifier {
    var action:() -> ()
    @State
    private var firstAppear = true
    func body(content: Content) -> some View {
        content
            .onAppear {
                guard firstAppear else {
                    return
                }
                firstAppear = false
                action()
            }
    }
}

// MARK: 提供onChange，默认的.onChange(of: value, initial: true)的行为是在值变化的时候触发、以及在onAppear的时候也触发。我们这个onChange(of: value, onLoad: true)只在页面打开的时候触发，和在后续值变化的时候触发。
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
extension View {
    @ViewBuilder
    public func onChange<V>(of value: V, onLoad: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some View where V : Equatable {
        if onLoad {
            self
        } else {
            self
                .onChange(of: value, initial: false, action)
        }
    }
}

@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
fileprivate
struct OnChange<V>: ViewModifier where V : Equatable {
    var value: V
    var action: (_ oldValue: V, _ newValue: V) -> Void
    func body(content: Content) -> some View {
        content
            .onLoad {
                action(value,value)
            }
            .onChange(of: value, initial: false, action)
    }
}
