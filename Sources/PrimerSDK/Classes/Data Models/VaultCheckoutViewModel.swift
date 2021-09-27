//
//  VaultCheckoutViewModel.swift
//  PrimerSDK
//
//  Created by Evangelos Pittas on 6/8/21.
//

import Foundation

#if canImport(UIKit)

internal protocol VaultCheckoutViewModelProtocol {
    var paymentMethods: [PaymentMethodToken] { get }
    var mandate: DirectDebitMandate { get }
    var availablePaymentOptions: [PaymentMethodViewModel] { get }
    var selectedPaymentMethodId: String { get }
    var amountStringed: String? { get }
    func loadConfig(_ completion: @escaping (Error?) -> Void)
    func authorizePayment(_ completion: @escaping (Error?) -> Void)
}

internal class VaultCheckoutViewModel: VaultCheckoutViewModelProtocol {
    var mandate: DirectDebitMandate {
        let state: AppStateProtocol = DependencyContainer.resolve()
        return state.directDebitMandate
    }

    var availablePaymentOptions: [PaymentMethodViewModel] {
        let state: AppStateProtocol = DependencyContainer.resolve()
        
        if !Primer.shared.flow.internalSessionFlow.vaulted {
            return state.viewModels.filter({ $0.type != .apaya })
        }
        
        return state.viewModels
    }

    var amountStringed: String? {
        if Primer.shared.flow.internalSessionFlow.vaulted { return nil }
        
        let settings: PrimerSettingsProtocol = DependencyContainer.resolve()
        guard let amount = settings.amount else { return "" }
        guard let currency = settings.currency else { return "" }
        return amount.toCurrencyString(currency: currency)
    }

    var paymentMethods: [PaymentMethodToken] {
        let state: AppStateProtocol = DependencyContainer.resolve()
        
        if #available(iOS 11.0, *) {
            return state.paymentMethods
        } else {
            return state.paymentMethods.filter {
                switch $0.paymentInstrumentType {
                case .goCardlessMandate: return true
                case .paymentCard: return true
                default: return false
                }
            }
        }
    }

    var selectedPaymentMethodId: String {
        let state: AppStateProtocol = DependencyContainer.resolve()
        return state.selectedPaymentMethod
    }

    deinit {
        log(logLevel: .debug, message: "🧨 deinit: \(self) \(Unmanaged.passUnretained(self).toOpaque())")
    }

    func loadConfig(_ completion: @escaping (Error?) -> Void) {
        let state: AppStateProtocol = DependencyContainer.resolve()
        if state.decodedClientToken.exists {
            let paymentMethodConfigService: PaymentMethodConfigServiceProtocol = DependencyContainer.resolve()
            paymentMethodConfigService.fetchConfig({ err in
                if let err = err {
                    completion(err)
                } else {
                    let vaultService: VaultServiceProtocol = DependencyContainer.resolve()
                    vaultService.loadVaultedPaymentMethods(completion)
                }
            })
        } else {
            let clientTokenService: ClientTokenServiceProtocol = DependencyContainer.resolve()
            clientTokenService.loadCheckoutConfig({ err in
                if let err = err {
                    completion(err)
                } else {
                    let paymentMethodConfigService: PaymentMethodConfigServiceProtocol = DependencyContainer.resolve()
                    paymentMethodConfigService.fetchConfig({ err in
                        if let err = err {
                            completion(err)
                        } else {
                            let vaultService: VaultServiceProtocol = DependencyContainer.resolve()
                            vaultService.loadVaultedPaymentMethods(completion)
                        }
                    })
                }
            })
        }
    }

    func authorizePayment(_ completion: @escaping (Error?) -> Void) {
        let state: AppStateProtocol = DependencyContainer.resolve()
        guard let paymentMethod = state.paymentMethods.first(where: { paymentMethod in
            return paymentMethod.token == state.selectedPaymentMethod
        }) else { return }
        
        let settings: PrimerSettingsProtocol = DependencyContainer.resolve()
        settings.authorizePayment(paymentMethod, completion)
        settings.onTokenizeSuccess(paymentMethod, completion)
    }

}

#endif
