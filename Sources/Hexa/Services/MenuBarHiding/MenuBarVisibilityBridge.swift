// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paulo Borini

import Foundation
import Security

/// The one boundary to macOS 27's private `MenuBarClientCore` framework, the
/// facility behind assessment (exam) mode: it takes an allow-list of bundles
/// and system items and macOS stops drawing every other status item.
///
/// Resolved at runtime on purpose. A macOS release that changes or removes the
/// framework turns into "unavailable", never into a launch failure.
enum MenuBarVisibilityBridge {
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    private static let configurationClassName = "MBAssessmentModeConfiguration"
    private static let assertionClassName = "MBAssessmentModeAssertion"

    /// Deliberately never closed: the classes it registers must outlive every
    /// object created from them, and the process is the only thing that ends.
    /// A `dlclose` would leave those classes dangling.
    private static let handle: UnsafeMutableRawPointer? = {
        dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL)
    }()

    static var isAvailable: Bool {
        guard handle != nil,
              let configuration = NSClassFromString(configurationClassName),
              let assertion = NSClassFromString(assertionClassName)
        else { return false }
        return class_getInstanceMethod(configuration, NSSelectorFromString(
            "initWithAllowedSystemItems:allowedBundleIdentifiers:")) != nil
            && class_getInstanceMethod(assertion, NSSelectorFromString(
                "activateWithConfiguration:completionHandler:")) != nil
            && class_getInstanceMethod(assertion, NSSelectorFromString("invalidate")) != nil
    }

    static var isDeveloperIDSigned: Bool {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(rawValue: 0), &code) == errSecSuccess,
              let code else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(rawValue: 0), &staticCode) == errSecSuccess,
              let staticCode else { return false }
        var signingInformation: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInformation) == errSecSuccess,
              let signingInformation,
              let values = signingInformation as? [String: Any],
              let certificates = values[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let certificate = certificates.first else { return false }
        let subject = SecCertificateCopySubjectSummary(certificate) as String?
        return MenuBarHidingSupport.isDeveloperIDCertificateSubject(subject)
    }

    /// Keeps only the given system items and apps visible; macOS hides every
    /// other status item and reflows the bar. Hiding lasts until the returned
    /// assertion is invalidated or this process exits, whichever comes first.
    static func activate(allowedSystemItems: [Int],
                         allowedBundleIdentifiers: [String],
                         completion: @escaping (Result<MenuBarVisibilityAssertion, Error>) -> Void) {
        guard isAvailable,
              let configurationClass = NSClassFromString(configurationClassName),
              let assertionClass = NSClassFromString(assertionClassName)
        else {
            completion(.failure(MenuBarVisibilityError(message: "MenuBarClientCore is unavailable")))
            return
        }

        // `alloc` returns a +1 reference, taken as retained. `init` /
        // `initWith…` return the same object without a second +1, so those
        // results are taken unretained; a second `takeRetainedValue` would
        // over-release. `AnyObject?` would make ARC treat `alloc` as +0.
        typealias AllocFunction = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
        typealias ConfigureFunction = @convention(c) (AnyObject, Selector, NSArray, NSArray) -> Unmanaged<AnyObject>?
        typealias InitFunction = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        typealias ActivateFunction = @convention(c) (AnyObject, Selector, AnyObject,
                                                    @convention(block) (NSError?) -> Void) -> Void

        let allocSelector = NSSelectorFromString("alloc")
        guard let allocImplementation = class_getMethodImplementation(object_getClass(configurationClass),
                                                                      allocSelector) else {
            completion(.failure(MenuBarVisibilityError(message: "MenuBarClientCore cannot allocate")))
            return
        }
        let alloc = unsafeBitCast(allocImplementation, to: AllocFunction.self)

        let configureSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        guard let configureImplementation = class_getMethodImplementation(configurationClass, configureSelector),
              let allocatedConfiguration = alloc(configurationClass as AnyClass, allocSelector)?.takeRetainedValue()
        else {
            completion(.failure(MenuBarVisibilityError(message: "MenuBarClientCore configuration is unavailable")))
            return
        }
        let configure = unsafeBitCast(configureImplementation, to: ConfigureFunction.self)
        guard let configuration = configure(allocatedConfiguration, configureSelector,
                                            allowedSystemItems.map { NSNumber(value: $0) } as NSArray,
                                            allowedBundleIdentifiers as NSArray)?.takeUnretainedValue() else {
            completion(.failure(MenuBarVisibilityError(message: "Could not build the visibility configuration")))
            return
        }

        guard let allocatedAssertion = alloc(assertionClass as AnyClass, allocSelector)?.takeRetainedValue() else {
            completion(.failure(MenuBarVisibilityError(message: "Could not allocate the assertion")))
            return
        }
        let initSelector = NSSelectorFromString("init")
        guard let initImplementation = class_getMethodImplementation(assertionClass, initSelector) else {
            completion(.failure(MenuBarVisibilityError(message: "Could not initialize the assertion")))
            return
        }
        let initialize = unsafeBitCast(initImplementation, to: InitFunction.self)
        guard let assertion = initialize(allocatedAssertion, initSelector)?.takeUnretainedValue() else {
            completion(.failure(MenuBarVisibilityError(message: "Could not initialize the assertion")))
            return
        }

        let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
        guard let activateImplementation = class_getMethodImplementation(assertionClass, activateSelector) else {
            completion(.failure(MenuBarVisibilityError(message: "Could not activate the assertion")))
            return
        }
        let activate = unsafeBitCast(activateImplementation, to: ActivateFunction.self)
        let handler: @convention(block) (NSError?) -> Void = { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(MenuBarVisibilityError(message: error.localizedDescription)))
                } else {
                    completion(.success(MenuBarVisibilityAssertion(raw: assertion)))
                }
            }
        }
        activate(assertion, activateSelector, configuration, handler)
    }
}

struct MenuBarVisibilityError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A held visibility restriction. Invalidating it hands every icon back.
final class MenuBarVisibilityAssertion {
    private var raw: AnyObject?

    init(raw: AnyObject) {
        self.raw = raw
    }

    func invalidate() {
        guard let raw else { return }
        self.raw = nil
        typealias InvalidateFunction = @convention(c) (AnyObject, Selector) -> Void
        let selector = NSSelectorFromString("invalidate")
        guard let implementation = class_getMethodImplementation(type(of: raw), selector) else { return }
        let invalidate = unsafeBitCast(implementation, to: InvalidateFunction.self)
        invalidate(raw, selector)
    }

    deinit {
        invalidate()
    }
}
