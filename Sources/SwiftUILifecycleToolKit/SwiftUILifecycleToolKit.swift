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
    public func onLoad(perform:@escaping () -> ()) -> some View {
        self
            .modifier(OnLoad(action: perform))
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
                .modifier(OnChange(value: value, action: action))
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

// MARK: 提供.task(onLoad:true)扩展，避免难以调试的Bug（意外触发了多次加载）
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
extension View {
    @ViewBuilder
    public func task(priority: TaskPriority = .userInitiated, onLoad: Bool, _ action: @escaping @Sendable () async -> Void) -> some View {
        if onLoad {
            self
                .modifier(TaskOnLoad(priority: priority, action: action))
        } else {
            self
                .task(priority: priority, action)
        }
    }
}

public
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
struct TaskOnLoad: ViewModifier {
    var priority: TaskPriority = .userInitiated
    var action: @Sendable () async -> Void
    public init(priority: TaskPriority, action: @Sendable @escaping () async -> Void) {
        self.priority = priority
        self.action = action
    }
    @State
    private var task:Task<Void,Never>? = nil
    public func body(content: Content) -> some View {
        content
            .onLoad {
                self.task = Task(priority: priority, operation: action)
            }
            .onDestroy {
                Task { @MainActor in
                    await MainActor.run {
                        self.task?.cancel()
                    }
                }
            }
    }
}

// MARK: NavigationStack的设计是，导航堆栈中的页面会保持自己的状态，而直接在页面上使用.onDisappear来做释放工作，会导致过早触发.onDisappear（在下一个页面Push出来的时候就触发了onDisappear）。使用.onDestroy，会在本页面Pop掉时才触发，完成清理工作。
@MainActor
fileprivate
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
class LifeDetector {
    private
    var onDestroy: @Sendable ()->()
    init(perform: @Sendable @escaping ()->()) {
        self.onDestroy = perform
    }
    deinit {
        self.onDestroy()
    }
}

fileprivate
@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
struct OnDestroyPack: ViewModifier {
    // 我持有这个对象，这样在我销毁的时候，这个对象也会销毁
    @State
    var mod:LifeDetector
    func body(content: Content) -> some View {
        content
    }
}

@available(iOS 17.0, watchOS 10.0, macOS 14.0, *)
extension View {
    @ViewBuilder
    public func onDestroy(perform: @escaping ()->()) -> some View {
        self
            .modifier(OnDestroyPack(mod:.init(perform: {
                // class的deinit会在任意线程被调用，让我们总是回到主线程，来处理SwiftUI托付给我们的perform闭包。
                Task { @MainActor in
                    await MainActor.run {
                        perform()
                    }
                }
            })))
    }
}

// 使用方法
//import SwiftUI
//
//struct ContentView: View {
//    @State
//    private var presentPage1 = false
//    var body: some View {
//        NavigationStack {
//            Button("Go Page1", action: {
//                presentPage1 = true
//            })
//            .navigationDestination(isPresented: $presentPage1, destination: {
//                Page1()
//            })
//        }
//    }
//}
//
//
//struct Page1: View {
//    @State
//    private var presentPage2 = false
//
//    var body: some View {
//
//        VStack(content: {
//            Button("Go Page2", action: {
//                presentPage2 = true
//            })
//        })
//        .onDestroy {
//            print("Page1页面销毁")
//        }
//        .navigationDestination(isPresented: $presentPage2, destination: {
//            Page2()
//        })
//    }
//}
//
//struct Page2: View {
//    var body: some View {
//        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Hello, world!@*/Text("Hello, world!")/*@END_MENU_TOKEN@*/
//    }
//}
//
//#Preview {
//    ContentView()
//}
//
