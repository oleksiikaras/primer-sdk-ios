//
//  AppState.swift
//  PrimerSDK
//
//  Created by Carl Eriksson on 16/01/2021.
//

#if canImport(UIKit)

internal protocol AppStateProtocol: AnyObject {
    
    var clientToken: String? { get set }
    var primerConfiguration: PrimerConfiguration? { get set }
    var paymentMethods: [PaymentMethodToken] { get set }
    var selectedPaymentMethodId: String? { get set }
    var selectedPaymentMethod: PaymentMethodToken? { get }
    var implementedReactNativeCallbacks: ImplementedReactNativeCallbacks? { get set }

}

internal class AppState: AppStateProtocol {
    
    var clientToken: String?
    var primerConfiguration: PrimerConfiguration?
    var paymentMethods: [PaymentMethodToken] = []
    var selectedPaymentMethodId: String?
    var selectedPaymentMethod: PaymentMethodToken? {
        guard let selectedPaymentMethodToken = selectedPaymentMethodId else { return nil }
        return paymentMethods.first(where: { $0.id == selectedPaymentMethodToken })
    }
    var implementedReactNativeCallbacks: ImplementedReactNativeCallbacks?

    deinit {
        log(logLevel: .debug, message: "🧨 deinit: \(self) \(Unmanaged.passUnretained(self).toOpaque())")
    }
}

public struct ImplementedReactNativeCallbacks: Codable {
    var isClientTokenCallbackImplemented: Bool
    var isTokenAddedToVaultImplemented: Bool
    var isOnResumeSuccessImplemented: Bool
    var isOnResumeErrorImplemented: Bool
    var isOnCheckoutDismissedImplemented: Bool
    var isCheckoutFailedImplemented: Bool
    var isClientSessionActionsImplemented: Bool
}

#endif
