//
//  AppState.swift
//  PrimerSDK
//
//  Created by Carl Eriksson on 16/01/2021.
//

protocol AppStateProtocol: class {
    //immutable
    var settings: PrimerSettingsProtocol { get }
    //mutable
    var viewModels: [PaymentMethodViewModel] { get set }
    var paymentMethods: [PaymentMethodToken] { get set }
    var selectedPaymentMethod: String { get set }
    var decodedClientToken: DecodedClientToken? { get set }
    var paymentMethodConfig: PaymentMethodConfig? { get set }
    var accessToken: String? { get set }
    var billingAgreementToken: String? { get set }
    var orderId: String? { get set }
    var confirmedBillingAgreement: PayPalConfirmBillingAgreementResponse? { get set }
    var approveURL: String? { get set }
}

class AppState: AppStateProtocol {
    
    let settings: PrimerSettingsProtocol
    
    var viewModels: [PaymentMethodViewModel] = []
    
    var paymentMethods: [PaymentMethodToken] = []
    
    var selectedPaymentMethod: String = ""
    
    var decodedClientToken: DecodedClientToken?
    
    var paymentMethodConfig: PaymentMethodConfig?
    
    var accessToken: String?
    
    var billingAgreementToken: String?
    
    var orderId: String?
    
    var confirmedBillingAgreement: PayPalConfirmBillingAgreementResponse?
    
    var approveURL: String?
    
    init(settings: PrimerSettingsProtocol) { self.settings = settings }
    
}