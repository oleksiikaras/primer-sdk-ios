import class Foundation.Thread
import Dispatch

/**
 A `Guarantee` is a functional abstraction around an asynchronous operation that cannot error.
 - See: `Thenable`
*/
internal final class Guarantee<T>: Thenable {
    let box: Box<T>

    fileprivate init(box: SealedBox<T>) {
        self.box = box as! Box<T>
    }

    /// Returns a `Guarantee` sealed with the provided value.
    internal static func value(_ value: T) -> Guarantee<T> {
        return .init(box: SealedBox(value: value))
    }

    /// Returns a pending `Guarantee` that can be resolved with the provided closure’s parameter.
    internal init(resolver body: (@escaping(T) -> Void) -> Void) {
        box = Box()
        body(box.seal)
    }

    /// Returns a pending `Guarantee` that can be resolved with the provided closure’s parameter.
    internal convenience init(cancellable: Cancellable, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(resolver: body)
       setCancellable(cancellable)
    }

    /// - See: `Thenable.pipe`
    internal func pipe(to: @escaping(Result<T, Error>) -> Void) {
        pipe{ to(.success($0)) }
    }

    func pipe(to: @escaping(T) -> Void) {
        switch box.inspect() {
        case .pending:
            box.inspect {
                switch $0 {
                case .pending(let handlers):
                    handlers.append(to)
                case .resolved(let value):
                    to(value)
                }
            }
        case .resolved(let value):
            to(value)
        }
    }

    /// - See: `Thenable.result`
    internal var result: Result<T, Error>? {
        switch box.inspect() {
        case .pending:
            return nil
        case .resolved(let value):
            return .success(value)
        }
    }

    final internal class Box<T>: EmptyBox<T> {
        var cancelled = false
        deinit {
            switch inspect() {
            case .pending:
                if !cancelled {
                    conf.logHandler(.pendingGuaranteeDeallocated)
                }
            case .resolved:
                break
            }
        }
    }

    init(_: PMKUnambiguousInitializer) {
        box = Box()
    }

    /// Returns a tuple of a pending `Guarantee` and a function that resolves it.
    internal class func pending() -> (guarantee: Guarantee<T>, resolve: (T) -> Void) {
        return { ($0, $0.box.seal) }(Guarantee<T>(.pending))
    }

    var cancellable: Cancellable?

    internal func setCancellable(_ cancellable: Cancellable) {
        if let gb = (box as? Guarantee<T>.Box<T>) {
            self.cancellable = CancellableWrapper(box: gb, cancellable: cancellable)
        } else {
            self.cancellable = cancellable
        }
    }

    final private class CancellableWrapper: Cancellable {
        let box: Guarantee<T>.Box<T>
        let cancellable: Cancellable

        init(box: Guarantee<T>.Box<T>, cancellable: Cancellable) {
            self.box = box
            self.cancellable = cancellable
        }

        func cancel() {
            box.cancelled = true
            cancellable.cancel()
        }

        var isCancelled: Bool {
            return cancellable.isCancelled
        }
    }
}

internal extension Guarantee {
    @discardableResult
    func done(on: Dispatcher = conf.D.return, _ body: @escaping(T) -> Void) -> Guarantee<Void> {
        let rg = Guarantee<Void>(.pending)
        pipe { (value: T) in
            on.dispatch {
                body(value)
                rg.box.seal(())
            }
        }
        return rg
    }

    func get(on: Dispatcher = conf.D.return, _ body: @escaping (T) -> Void) -> Guarantee<T> {
        return map(on: on) {
            body($0)
            return $0
        }
    }

    func map<U>(on: Dispatcher = conf.D.map, _ body: @escaping(T) -> U) -> Guarantee<U> {
        let rg = Guarantee<U>(.pending)
        pipe { value in
            on.dispatch {
                rg.box.seal(body(value))
            }
        }
        return rg
    }

	@discardableResult
    func then<U>(on: Dispatcher = conf.D.map, _ body: @escaping(T) -> Guarantee<U>) -> Guarantee<U> {
        let rg = Guarantee<U>(.pending)
        pipe { value in
            on.dispatch {
                body(value).pipe(to: rg.box.seal)
            }
        }
        return rg
    }

    func asVoid() -> Guarantee<Void> {
        return map(on: nil) { _ in }
    }

    /**
     Blocks this thread, so you know, don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    func wait() -> T {

        if Thread.isMainThread {
            conf.logHandler(.waitOnMainThread)
        }

        var result = value

        if result == nil {
            let group = DispatchGroup()
            group.enter()
            pipe { (foo: T) in result = foo; group.leave() }
            group.wait()
        }

        return result!
    }
}

internal extension Guarantee where T: Sequence {
    /**
     `Guarantee<[T]>` => `T` -> `U` => `Guarantee<[U]>`

         Guarantee.value([1,2,3])
            .mapValues { integer in integer * 2 }
            .done {
                // $0 => [2,4,6]
            }
     */
    func mapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) -> U) -> Guarantee<[U]> {
        return map(on: on, flags: flags) { $0.map(transform) }
    }

    /**
     `Guarantee<[T]>` => `T` -> `[U]` => `Guarantee<[U]>`

         Guarantee.value([1,2,3])
            .flatMapValues { integer in [integer, integer] }
            .done {
                // $0 => [1,1,2,2,3,3]
            }
     */
    func flatMapValues<U: Sequence>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) -> U) -> Guarantee<[U.Iterator.Element]> {
        return map(on: on, flags: flags) { (foo: T) in
            foo.flatMap { transform($0) }
        }
    }

    /**
     `Guarantee<[T]>` => `T` -> `U?` => `Guarantee<[U]>`

         Guarantee.value(["1","2","a","3"])
            .compactMapValues { Int($0) }
            .done {
                // $0 => [1,2,3]
            }
     */
    func compactMapValues<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) -> U?) -> Guarantee<[U]> {
        return map(on: on, flags: flags) { foo -> [U] in
            #if !swift(>=3.3) || (swift(>=4) && !swift(>=4.1))
            return foo.flatMap(transform)
            #else
            return foo.compactMap(transform)
            #endif
        }
    }

    /**
     `Guarantee<[T]>` => `T` -> `Guarantee<U>` => `Guarantee<[U]>`

         Guarantee.value([1,2,3])
            .thenMap { .value($0 * 2) }
            .done {
                // $0 => [2,4,6]
            }
     */
    func thenMap<U>(on: Dispatcher = conf.D.map, _ transform: @escaping(T.Iterator.Element) -> Guarantee<U>) -> Guarantee<[U]> {
        return then(on: on) {
            when(fulfilled: $0.map(transform))
        }.recover {
            // if happens then is bug inside PromiseKit
            fatalError(String(describing: $0))
        }
    }

    /**
     `Guarantee<[T]>` => `T` -> `Guarantee<[U]>` => `Guarantee<[U]>`

         Guarantee.value([1,2,3])
            .thenFlatMap { integer in .value([integer, integer]) }
            .done {
                // $0 => [1,1,2,2,3,3]
            }
     */
    func thenFlatMap<U: Thenable>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ transform: @escaping(T.Iterator.Element) -> U) -> Guarantee<[U.T.Iterator.Element]> where U.T: Sequence {
        return then(on: on, flags: flags) {
            when(fulfilled: $0.map(transform))
        }.map(on: nil) {
            $0.flatMap { $0 }
        }.recover {
            // if happens then is bug inside PromiseKit
            fatalError(String(describing: $0))
        }
    }

    /**
     `Guarantee<[T]>` => `T` -> Bool => `Guarantee<[T]>`

         Guarantee.value([1,2,3])
            .filterValues { $0 > 1 }
            .done {
                // $0 => [2,3]
            }
     */
    func filterValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ isIncluded: @escaping(T.Iterator.Element) -> Bool) -> Guarantee<[T.Iterator.Element]> {
        return map(on: on, flags: flags) {
            $0.filter(isIncluded)
        }
    }

    /**
     `Guarantee<[T]>` => (`T`, `T`) -> Bool => `Guarantee<[T]>`

     Guarantee.value([5,2,3,4,1])
        .sortedValues { $0 > $1 }
        .done {
            // $0 => [5,4,3,2,1]
        }
     */
    func sortedValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, _ areInIncreasingOrder: @escaping(T.Iterator.Element, T.Iterator.Element) -> Bool) -> Guarantee<[T.Iterator.Element]> {
        return map(on: on, flags: flags) {
            $0.sorted(by: areInIncreasingOrder)
        }
    }
}

internal extension Guarantee where T: Sequence, T.Iterator.Element: Comparable {
    /**
     `Guarantee<[T]>` => `Guarantee<[T]>`

     Guarantee.value([5,2,3,4,1])
        .sortedValues()
        .done {
            // $0 => [1,2,3,4,5]
        }
     */
    func sortedValues(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil) -> Guarantee<[T.Iterator.Element]> {
        return map(on: on, flags: flags) { $0.sorted() }
    }
}

internal extension Guarantee where T == Void {
    convenience init() {
        self.init(box: SealedBox(value: Void()))
    }

    static var value: Guarantee<Void> {
        return .value(Void())
    }

    convenience init(resolver body: (@escaping() -> Void) -> Void) {
        self.init(resolver: { seal in
            body {
                seal(())
            }
        })
    }
}

internal extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue, yielding a `Guarantee`.

         DispatchQueue.global().async(.promise) {
             md5(input)
         }.done { md5 in
             //…
         }

     - _: Must be `.promise` to distinguish from standard `DispatchQueue.async`
     - group: A `DispatchGroup`, as for standard `DispatchQueue.async`
     - qos: A quality-of-service grade, as for standard `DispatchQueue.async`
     - flags: Work item flags, as for standard `DispatchQueue.async`
     - body: A closure that yields a value to resolve the guarantee.
     - Returns: A new `Guarantee` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    final func async<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS? = nil, flags: DispatchWorkItemFlags? = nil, execute body: @escaping () -> T) -> Guarantee<T> {
        let rg = Guarantee<T>(.pending)
        asyncD(group: group, qos: qos, flags: flags) {
            rg.box.seal(body())
        }
        return rg
    }
}

internal extension Dispatcher {
    /**
     Executes the provided closure on a `Dispatcher`, yielding a `Guarantee`
     that represents the value ultimately returned by the closure.

         dispatcher.dispatch {
            md5(input)
         }.done { md5 in
            //…
         }

     - Parameter body: The closure that yields the value of the Guarantee.
     - Returns: A new `Guarantee` resolved by the result of the provided closure.
     */
    func dispatch<T>(_ body: @escaping () -> T) -> Guarantee<T> {
        let rg = Guarantee<T>(.pending)
        dispatch {
            rg.box.seal(body())
        }
        return rg
    }
}

#if os(Linux)
import func CoreFoundation._CFIsMainThread

extension Thread {
    // `isMainThread` is not implemented yet in swift-corelibs-foundation.
    static var isMainThread: Bool {
        return _CFIsMainThread()
    }
}
#endif
