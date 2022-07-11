//
//  ClientSessionActionsModule.swift
//  PrimerSDK
//
//  Created by Evangelos on 11/7/22.
//

#if canImport(UIKit)

import Foundation

protocol ClientSessionActionsProtocol {
    
    func selectPaymentMethodIfNeeded(_ paymentMethod: PrimerPaymentMethodType, cardNetwork: String?) -> Promise<Void>
    func unselectPaymentMethodIfNeeded() -> Promise<Void>
    func dispatch(actions: [ClientSessionAPIResponse.Action]) -> Promise<Void>
}

class ClientSessionActionsModule: ClientSessionActionsProtocol {
    
    func selectPaymentMethodIfNeeded(_ paymentMethod: PrimerPaymentMethodType, cardNetwork: String?) -> Promise<Void> {
        return Promise { seal in
            guard Primer.shared.intent == .checkout else {
                seal.fulfill()
                return
            }
            
            var params: [String: Any] = ["paymentMethodType": paymentMethod.rawValue]
            
            if let cardNetwork = cardNetwork {
                params["binData"] = [
                    "network": cardNetwork
                ]
            }
            let actions = [ClientSessionAPIResponse.Action.selectPaymentMethodActionWithParameters(params)]
            
            let clientSessionService: ClientSessionServiceProtocol = DependencyContainer.resolve()
            let clientSessionActionsRequest = ClientSessionUpdateRequest(actions: ClientSessionAction(actions: actions))
            
            PrimerDelegateProxy.primerClientSessionWillUpdate()
            
            firstly {
                clientSessionService.requestPrimerConfigurationWithActions(actionsRequest: clientSessionActionsRequest)
            }
            .done { primerApiConfiguration in
                AppState.current.apiConfiguration = primerApiConfiguration
                PrimerDelegateProxy.primerClientSessionDidUpdate(PrimerClientSession(from: primerApiConfiguration))
                seal.fulfill()
            }
            .catch { error in
                seal.reject(error)
            }
        }
    }
    
    func unselectPaymentMethodIfNeeded() -> Promise<Void> {
        return Promise { seal in
            guard Primer.shared.intent == .checkout else {
                seal.fulfill()
                return
            }
            
            let unselectPaymentMethodAction = ClientSessionAPIResponse.Action(type: .unselectPaymentMethod, params: nil)
            let clientSessionService: ClientSessionServiceProtocol = DependencyContainer.resolve()
            let clientSessionActionsRequest = ClientSessionUpdateRequest(actions: ClientSessionAction(actions: [unselectPaymentMethodAction]))
            
            PrimerDelegateProxy.primerClientSessionWillUpdate()
            
            firstly {
                clientSessionService.requestPrimerConfigurationWithActions(actionsRequest: clientSessionActionsRequest)
            }
            .done { primerApiConfiguration in
                AppState.current.apiConfiguration = primerApiConfiguration
                PrimerDelegateProxy.primerClientSessionDidUpdate(PrimerClientSession(from: primerApiConfiguration))
                seal.fulfill()
            }
            .catch { error in
                seal.reject(error)
            }
        }
    }
    
    func dispatch(actions: [ClientSessionAPIResponse.Action]) -> Promise<Void> {
        return Promise { seal in
            let clientSessionService: ClientSessionServiceProtocol = DependencyContainer.resolve()
            let clientSessionActionsRequest = ClientSessionUpdateRequest(actions: ClientSessionAction(actions: actions))
            
            PrimerDelegateProxy.primerClientSessionWillUpdate()
            
            firstly {
                clientSessionService.requestPrimerConfigurationWithActions(actionsRequest: clientSessionActionsRequest)
            }
            .done { primerApiConfiguration in
                AppState.current.apiConfiguration = primerApiConfiguration
                PrimerDelegateProxy.primerClientSessionDidUpdate(PrimerClientSession(from: primerApiConfiguration))
                seal.fulfill()
            }
            .catch { error in
                seal.reject(error)
            }
        }
    }
}

#endif
