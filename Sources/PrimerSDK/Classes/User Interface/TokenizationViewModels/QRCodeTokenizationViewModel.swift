//
//  QRCodeTokenizationViewModel.swift
//  PrimerSDK
//
//  Created by Evangelos on 11/1/22.
//

#if canImport(UIKit)

import SafariServices
import UIKit

class QRCodeTokenizationViewModel: ExternalPaymentMethodTokenizationViewModel {
    
    private var tokenizationService: TokenizationServiceProtocol?
    internal var qrCode: String?
    private var didCancel: (() -> Void)?
    
    deinit {
        tokenizationService = nil
        qrCode = nil
        log(logLevel: .debug, message: "🧨 deinit: \(self) \(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    override func validate() throws {
        guard let decodedClientToken = ClientTokenService.decodedClientToken, decodedClientToken.isValid else {
            let err = PrimerError.invalidClientToken(userInfo: ["file": #file, "class": "\(Self.self)", "function": #function, "line": "\(#line)"])
            ErrorHandler.handle(error: err)
            throw err
        }
    }
    
    override func startTokenizationFlow() -> Promise<PrimerPaymentMethodTokenData> {
        let event = Analytics.Event(
            eventType: .ui,
            properties: UIEventProperties(
                action: .click,
                context: Analytics.Event.Property.Context(
                    issuerId: nil,
                    paymentMethodType: self.config.type.rawValue,
                    url: nil),
                extra: nil,
                objectType: .button,
                objectId: .select,
                objectClass: "\(Self.self)",
                place: .bankSelectionList))
        Analytics.Service.record(event: event)
        
        return Promise { seal in
            firstly {
                self.validateReturningPromise()
            }
            .then { () -> Promise<Void> in
                self.handlePrimerWillCreatePaymentEvent(PaymentMethodData(type: self.config.type))
            }
            .then {
                self.tokenize()
            }
            .done { tmpPaymentMethodTokenData in
                seal.fulfill(tmpPaymentMethodTokenData)
            }
            .catch { err in
                seal.reject(err)
            }
        }
    }
    
    func cancel() {
        didCancel?()
    }
    
    fileprivate func tokenize() -> Promise<PaymentMethodToken> {
        return Promise { seal in
            guard let configId = config.id else {
                let err = PrimerError.invalidValue(key: "configuration.id", value: config.id, userInfo: ["file": #file, "class": "\(Self.self)", "function": #function, "line": "\(#line)"])
                ErrorHandler.handle(error: err)
                seal.reject(err)
                return
            }
            
            let settings: PrimerSettingsProtocol = DependencyContainer.resolve()
            var sessionInfo: AsyncPaymentMethodOptions.SessionInfo?
            if let localeCode = settings.localeData.localeCode {
                sessionInfo = AsyncPaymentMethodOptions.SessionInfo(locale: localeCode)
            }
            
            let request = AsyncPaymentMethodTokenizationRequest(
                paymentInstrument: AsyncPaymentMethodOptions(
                    paymentMethodType: config.type,
                    paymentMethodConfigId: configId,
                    sessionInfo: sessionInfo))
            
            let tokenizationService: TokenizationServiceProtocol = TokenizationService()
            firstly {
                tokenizationService.tokenize(request: request)
            }
            .done{ paymentMethod in
                seal.fulfill(paymentMethod)
            }
            .catch { err in
                seal.reject(err)
            }
        }
    }
    
    override func handleDecodedClientTokenIfNeeded(_ decodedClientToken: DecodedClientToken) -> Promise<String?> {
        return Promise { seal in
            if let statusUrlStr = decodedClientToken.statusUrl,
               let statusUrl = URL(string: statusUrlStr),
               decodedClientToken.intent != nil {
                
                firstly {
                    self.presentQRCodePaymentMethod()
                }
                .then { () -> Promise<String> in
                    return self.startPolling(on: statusUrl)
                }
                .done { resumeToken in
                    seal.fulfill(resumeToken)
                }
                .catch { err in
                    seal.reject(err)
                }
            } else {
                let error = PrimerError.invalidClientToken(userInfo: ["file": #file, "class": "\(Self.self)", "function": #function, "line": "\(#line)"])
                seal.reject(error)
            }
        }
    }
    
    fileprivate func presentQRCodePaymentMethod() -> Promise<Void> {
        return Promise { seal in
            let qrcvc = QRCodeViewController(viewModel: self)
            self.willPresentPaymentMethodUI?()
            Primer.shared.primerRootVC?.show(viewController: qrcvc)
            self.didPresentPaymentMethodUI?()
            seal.fulfill(())
        }
    }
    
    internal override func startPolling(on url: URL) -> Promise<String> {
        let p: Promise? = Promise<String> { seal in
            self.didCancel = {
                let err = PrimerError.cancelled(paymentMethodType: .xfers, userInfo: ["file": #file, "class": "\(Self.self)", "function": #function, "line": "\(#line)"])
                ErrorHandler.handle(error: err)
                seal.reject(err)
                self.pollingRetryTimer?.invalidate()
                self.pollingRetryTimer = nil
                return
            }
            
            self.startPolling(on: url) { (id, err) in
                if let err = err {
                    seal.reject(err)
                } else if let id = id {
                    seal.fulfill(id)
                } else {
                    assert(true, "Should have received one parameter")
                }
            }
        }
        
        return p!
    }
    
    var pollingRetryTimer: Timer?
    
    fileprivate func startPolling(on url: URL, completion: @escaping (_ id: String?, _ err: Error?) -> Void) {
        let client: PrimerAPIClientProtocol = DependencyContainer.resolve()
        client.poll(clientToken: ClientTokenService.decodedClientToken, url: url.absoluteString) { result in
            switch result {
            case .success(let res):
                if res.status == .pending {
                    self.pollingRetryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                        self.startPolling(on: url, completion: completion)
                        self.pollingRetryTimer?.invalidate()
                        self.pollingRetryTimer = nil
                    }
                } else if res.status == .complete {
                    completion(res.id, nil)
                } else {
                    // Do what here?
                    fatalError()
                }
            case .failure(let err):
                let nsErr = err as NSError
                if nsErr.domain == NSURLErrorDomain && nsErr.code == -1001 {
                    // Retry
                    self.pollingRetryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                        self.startPolling(on: url, completion: completion)
                        self.pollingRetryTimer?.invalidate()
                        self.pollingRetryTimer = nil
                    }
                } else {
                    completion(nil, err)
                }
            }
        }
    }
}

#endif

