//
// Resolver.swift
//
// GitHub Repo and Documentation: https://github.com/hmlongco/Resolver
//
// Copyright © 2017 Michael Long. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if os(iOS)
import UIKit
#else
import Foundation
#endif

// swiftlint:disable file_length

public protocol ResolverRegistering {
    static func registerAllServices()
}

/// The Resolving protocol is used to make the Resolver registries available to a given class.
public protocol Resolving {
    var resolver: Resolver { get }
}

extension Resolving {
    public var resolver: Resolver {
        Resolver.root
    }
}

/// Resolver is a Dependency Injection registry that registers Services for later resolution and
/// injection into newly constructed instances.
public final class Resolver {
    private static let syncQueue = DispatchQueue(label: "resolver.Resolver.syncQueue.serial", qos: .userInitiated)
    private static let noName = "*"
    private let parent: Resolver?
    private var registrations = [Int : [String : Any]]()

    // MARK: - Defaults

    /// Default registry used by the static Registration functions.
    public static let main = Resolver()
    /// Default registry used by the static Resolution functions and by the Resolving protocol.
    public static var root: Resolver = main
    /// Default scope applied when registering new objects.
    public static var defaultScope: ResolverScope = Resolver.graph

    // MARK: - Lifecycle

    public init(parent: Resolver? = nil) {
        self.parent = parent
    }

    /// Called by the Resolution functions to perform one-time initialization of the Resolver registries.
    public final func registerServices() {
        Resolver.registerServices?()
    }

    /// Called by the Resolution functions to perform one-time initialization of the Resolver registries.
    public static var registerServices: (() -> Void)? = {
        syncQueue.sync {
            if Resolver.registerServices != nil, let registering = (Resolver.root as Any) as? ResolverRegistering {
                type(of: registering).registerAllServices()
            }
            Resolver.registerServices = nil
        }
    }

    // MARK: - Service Registration

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                         factory: @escaping ResolverFactory<Service>) -> ResolverOptions<Service> {
        main.register(type, name: name, factory: { (_, _) -> Service? in factory() })
    }

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                         factory: @escaping ResolverFactoryResolver<Service>) -> ResolverOptions<Service> {
        main.register(type, name: name, factory: { (r, _) -> Service? in factory(r) })
    }

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                         factory: @escaping ResolverFactoryArguments<Service>) -> ResolverOptions<Service> {
        main.register(type, name: name, factory: factory)
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                        factory: @escaping ResolverFactory<Service>) -> ResolverOptions<Service> {
        register(type, name: name, factory: { (_, _) -> Service? in factory() })
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                        factory: @escaping ResolverFactoryResolver<Service>) -> ResolverOptions<Service> {
        register(type, name: name, factory: { (r, _) -> Service? in factory(r) })
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(_ type: Service.Type = Service.self, name: String? = nil,
                                        factory: @escaping ResolverFactoryArguments<Service>) -> ResolverOptions<Service> {
        let key = ObjectIdentifier(Service.self).hashValue
        let registration = ResolverRegistration(resolver: self, key: key, name: name, factory: factory)
        if var container = registrations[key] {
            container[name ?? Resolver.noName] = registration
            registrations[key] = container
        } else {
            registrations[key] = [name ?? Resolver.noName : registration]
        }
        return registration
    }

    // MARK: - Service Resolution

    /// Static function calls the root registry to resolve a given Service type.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    public static func resolve<Service>(_ type: Service.Type = Service.self, name: String? = nil, args: Any? = nil) -> Service {
        Resolver.registerServices?() // always check initial registrations first in case registerAllServices swaps root
        return root.resolve(type, name: name, args: args)
    }

    /// Resolves and returns an instance of the given Service type from the current registry or from its
    /// parent registries.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public final func resolve<Service>(_ type: Service.Type = Service.self, name: String? = nil, args: Any? = nil) -> Service {
        if let registration = lookup(type, name: name ?? Resolver.noName),
           let service = registration.scope.resolve(resolver: self, registration: registration, args: args) {
            return service
        }
        print("RESOLVER: '\(Service.self):\(name ?? "")' not resolved. To disambiguate optionals use resolver.optional().")
        fatalError()
    }

    /// Static function calls the root registry to resolve an optional Service type.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public static func optional<Service>(_ type: Service.Type = Service.self, name: String? = nil, args: Any? = nil) -> Service? {
        Resolver.registerServices?() // always check initial registrations first in case registerAllServices swaps root
        return root.optional(type, name: name, args: args)
    }

    /// Resolves and returns an optional instance of the given Service type from the current registry or
    /// from its parent registries.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public final func optional<Service>(_ type: Service.Type = Service.self, name: String? = nil, args: Any? = nil) -> Service? {
        if let registration = lookup(type, name: name ?? Resolver.noName),
           let service = registration.scope.resolve(resolver: self, registration: registration, args: args) {
            return service
        }
        return nil
    }

    // MARK: - Internal

    /// Internal function searches the current and parent registries for a ResolverRegistration<Service> that matches
    /// the supplied type and name.
    private final func lookup<Service>(_ type: Service.Type, name: String) -> ResolverRegistration<Service>? {
        Resolver.registerServices?()
        if let container = registrations[ObjectIdentifier(Service.self).hashValue] {
            return container[name] as? ResolverRegistration<Service>
        }
        if let parent = parent, let registration = parent.lookup(type, name: name) {
            return registration
        }
        return nil
    }
}

// Registration Internals

public typealias ResolverFactory<Service> = () -> Service?
public typealias ResolverFactoryResolver<Service> = (_ resolver: Resolver) -> Service?
public typealias ResolverFactoryArguments<Service> = (_ resolver: Resolver, _ args: Any?) -> Service?
public typealias ResolverFactoryMutator<Service> = (_ resolver: Resolver, _ service: Service) -> Void
public typealias ResolverFactoryMutatorArguments<Service> = (_ resolver: Resolver, _ service: Service, _ args: Any?) -> Void

/// A ResolverOptions instance is returned by a registration function in order to allow additional configuration. (e.g. scopes, etc.)
public class ResolverOptions<Service> {
    // MARK: - Parameters

    public var scope: ResolverScope

    fileprivate var factory: ResolverFactoryArguments<Service>
    fileprivate var mutator: ResolverFactoryMutatorArguments<Service>?
    fileprivate weak var resolver: Resolver?

    // MARK: - Lifecycle

    public init(resolver: Resolver, factory: @escaping ResolverFactoryArguments<Service>) {
        self.factory = factory
        self.resolver = resolver
        self.scope = Resolver.defaultScope
    }

    // MARK: - Functionality

    /// Indicates that the registered Service also implements a specific protocol that may be resolved on
    /// its own.
    ///
    /// - parameter type: Type of protocol being registered.
    /// - parameter name: Named variant of protocol being registered.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func implements<Protocol>(_ type: Protocol.Type, name: String? = nil) -> ResolverOptions<Service> {
        resolver?.register(type.self, name: name) { r, _ in r.resolve(Service.self) as? Protocol }
        return self
    }

    /// Allows easy assignment of injected properties into resolved Service.
    ///
    /// - parameter block: Resolution block.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func resolveProperties(_ block: @escaping ResolverFactoryMutator<Service>) -> ResolverOptions<Service> {
        mutator = { r, s, _ in block(r, s) }
        return self
    }

    /// Allows easy assignment of injected properties into resolved Service.
    ///
    /// - parameter block: Resolution block that also receives resolution arguments.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func resolveProperties(_ block: @escaping ResolverFactoryMutatorArguments<Service>) -> ResolverOptions<Service> {
        mutator = block
        return self
    }

    /// Defines scope in which requested Service may be cached.
    ///
    /// - parameter block: Resolution block.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func scope(_ scope: ResolverScope) -> ResolverOptions<Service> {
        self.scope = scope
        return self
    }

}

/// ResolverRegistration stores a service definition and its factory closure.
public final class ResolverRegistration<Service>: ResolverOptions<Service> {
    // MARK: Parameters

    public let key: Int
    public let cacheKey: String

    // MARK: Lifecycle

    public init(resolver: Resolver, key: Int, name: String?, factory: @escaping ResolverFactoryArguments<Service>) {
        self.key = key
        if let namedService = name {
            self.cacheKey = String(key) + ":" + namedService
        } else {
            self.cacheKey = String(key)
        }
        super.init(resolver: resolver, factory: factory)
    }

    // MARK: Functions

    public final func resolve(resolver: Resolver, args: Any?) -> Service? {
        guard let service = factory(resolver, args) else {
            return nil
        }
        self.mutator?(resolver, service, args)
        return service
    }
}

// Scopes

extension Resolver {
    // MARK: - Scopes

    /// All application scoped services exist for lifetime of the app. (e.g Singletons)
    public static let application = ResolverScopeApplication()
    /// Cached services exist for lifetime of the app or until their cache is reset.
    public static let cached = ResolverScopeCache()
    /// Graph services are initialized once and only once during a given resolution cycle. This is the default scope.
    public static let graph = ResolverScopeGraph()
    /// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
    public static let shared = ResolverScopeShare()
    /// Unique services are created and initialized each and every time they're resolved.
    public static let unique = ResolverScopeUnique()
}

/// Resolver scopes exist to control when resolution occurs and how resolved instances are cached. (If at all.)
public protocol ResolverScope: class {
    func resolve<Service>(resolver: Resolver, registration: ResolverRegistration<Service>, args: Any?) -> Service?
}

/// All application scoped services exist for lifetime of the app. (e.g Singletons)
public class ResolverScopeApplication: ResolverScope {
    @Sync
    fileprivate var cachedServices = [String : Any](minimumCapacity: 32)

    public final func resolve<Service>(resolver: Resolver, registration: ResolverRegistration<Service>, args: Any?) -> Service? {
        let existingService = cachedServices[registration.cacheKey] as? Service

        if let service = existingService {
            return service
        }

        let service = registration.resolve(resolver: resolver, args: args)

        if let service = service {
            cachedServices[registration.cacheKey] = service
        }

        return service
    }
}

/// Cached services exist for lifetime of the app or until their cache is reset.
public final class ResolverScopeCache: ResolverScopeApplication {
    public func reset() {
        cachedServices.removeAll()
    }
}

/// Graph services are initialized once and only once during a given resolution cycle. This is the default scope.
public final class ResolverScopeGraph: ResolverScope {
    private let syncQueue = DispatchQueue(label: "resolver.ResolverScopeGraph.syncQueue.serial", qos: .userInitiated)
    private var graph = [String : Any?](minimumCapacity: 32)
    private var resolutionDepth = 0

    public final func resolve<Service>(resolver: Resolver, registration: ResolverRegistration<Service>, args: Any?) -> Service? {
        var s: Service?
        syncQueue.sync {
            s = self.graph[registration.cacheKey] as? Service
            if s != nil { self.resolutionDepth += 1 }
        }

        if let existingService = s {
            return existingService
        }

        let service = registration.resolve(resolver: resolver, args: args)

        syncQueue.sync {
            self.resolutionDepth -= 1

            if self.resolutionDepth == 0 {
                graph.removeAll()
            } else if let service = service, type(of: service as Any) is AnyClass {
                self.graph[registration.cacheKey] = service
            }
        }

        return service
    }
}

/// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
public final class ResolverScopeShare: ResolverScope {
    @Sync
    private var cachedServices = [String : BoxWeak](minimumCapacity: 32)

    public final func resolve<Service>(resolver: Resolver, registration: ResolverRegistration<Service>, args: Any?) -> Service? {
        let existingService = cachedServices[registration.cacheKey]?.service as? Service

        if let service = existingService {
            return service
        }

        let service = registration.resolve(resolver: resolver, args: args)

        if let service = service, type(of: service as Any) is AnyClass {
            cachedServices[registration.cacheKey] = BoxWeak(service: service as AnyObject)
        }

        return service
    }

    public final func reset() {
        cachedServices.removeAll()
    }

    private struct BoxWeak {
        weak var service: AnyObject?
    }
}

/// Unique services are created and initialized each and every time they're resolved.
public final class ResolverScopeUnique: ResolverScope {
    public final func resolve<Service>(resolver: Resolver, registration: ResolverRegistration<Service>, args: Any?) -> Service? {
        registration.resolve(resolver: resolver, args: args)
    }
}

#if os(iOS)
/// Storyboard Automatic Resolution Protocol
public protocol StoryboardResolving: Resolving {
    func resolveViewController()
}

/// Storyboard Automatic Resolution Trigger
public extension UIViewController {
    // swiftlint:disable unused_setter_value
    dynamic var resolving: Bool {
        get {
            true
        }
        set {
            if let vc = self as? StoryboardResolving {
                vc.resolveViewController()
            }
        }
    }
    // swiftlint:enable unused_setter_value
}
#endif

// Swift Property Wrappers

/// Immediate injection property wrapper.
///
/// Wrapped dependent service is resolved immediately using Resolver.root upon struct initialization.
///
@propertyWrapper
public struct Injected<Service> {
    private var service: Service
    public init() {
        self.service = Resolver.resolve(Service.self)
    }
    public init(name: String? = nil, container: Resolver? = nil) {
        self.service = container?.resolve(Service.self, name: name) ?? Resolver.resolve(Service.self, name: name)
    }
    public var wrappedValue: Service {
        get { service }
        mutating set { service = newValue }
    }
    public var projectedValue: Injected<Service> {
        get { self }
        mutating set { self = newValue }
    }
}

/// Lazy injection property wrapper. Note that embedded container and name properties will be used if set prior to service instantiation.
///
/// Wrapped dependent service is not resolved until service is accessed.
///
@propertyWrapper
public struct LazyInjected<Service> {
    private var service: Service!
    public var container: Resolver?
    public var name: String?
    public init() {}
    public init(name: String? = nil, container: Resolver? = nil) {
        self.name = name
        self.container = container
    }
    public var isEmpty: Bool {
        service == nil
    }
    public var wrappedValue: Service {
        mutating get {
            if self.service == nil {
                self.service = container?.resolve(Service.self, name: name) ?? Resolver.resolve(Service.self, name: name)
            }
            return service
        }
        mutating set { service = newValue  }
    }
    public var projectedValue: LazyInjected<Service> {
        get { self }
        mutating set { self = newValue }
    }
    public mutating func release() {
        self.service = nil
    }
}

@propertyWrapper
private final class Sync<T: Collection> {
    private let syncQueue = DispatchQueue(label: "resolver.Sync<\(String(describing: T.self))>.concurrent", qos: .userInitiated, attributes: .concurrent)
    private var _wrappedValue: T
    var wrappedValue: T {
        get { syncQueue.sync { _wrappedValue } }
        set { syncQueue.async(flags: .barrier) { self._wrappedValue = newValue } }
    }

    init(wrappedValue: T) {
        _wrappedValue = wrappedValue
    }
}
