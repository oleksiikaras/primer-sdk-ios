#if canImport(UIKit)

#if canImport(Primer3DS)
import Primer3DS
#endif
import UIKit

// swiftlint:disable identifier_name
private let _Primer = Primer()
// swiftlint:enable identifier_name

public class Primer {
    
    // MARK: - PROPERTIES
    internal var primerWindow: UIWindow?
    public var delegate: PrimerDelegate? // TODO: should this be weak?
    internal var flow: PrimerSessionFlow!
    internal var presentingViewController: UIViewController?
    internal var primerRootVC: PrimerRootViewController?
    internal let sdkSessionId = UUID().uuidString
    internal var checkoutSessionId: String?
    private var timingEventId: String?

    // MARK: - INITIALIZATION

    public static var shared: Primer {
        return _Primer
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    fileprivate init() {
        #if canImport(Primer3DS)
        print("Can import Primer3DS")
        #else
        print("Failed to import Primer3DS")
        #endif
        
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(onAppStateChange), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAppStateChange), name: UIApplication.willResignActiveNotification, object: nil)
        
        #if DEBUG
        do {
            try Analytics.Service.deleteEvents()
        } catch {
            fatalError(error.localizedDescription)
        }
        #endif
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        #if canImport(Primer3DS)
        return Primer3DS.application(app, open: url, options: options)
        #endif
        
        return false
    }

    public func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        #if canImport(Primer3DS)
        return Primer3DS.application(application, continue: userActivity, restorationHandler: restorationHandler)
        #endif
        
        return false
    }
    
    @objc
    private func onAppStateChange() {
        Analytics.Service.sync()
    }

    // MARK: - CONFIGURATION

    /**
     Configure SDK's settings and/or theme
     */

    public func configure(settings: PrimerSettings2? = nil, delegate: PrimerDelegate? = nil) {
        DependencyContainer.register((settings ?? PrimerSettings2()) as PrimerSettingsProtocol2)
        self.delegate = delegate
    }
    
    // MARK: - SHOW

    /**
     Show Primer Checkout
     */

    public func showUniversalCheckout(clientToken: String, completion: ((Error?) -> Void)? = nil) {
        checkoutSessionId = UUID().uuidString
        
        let sdkEvent = Analytics.Event(
            eventType: .sdkEvent,
            properties: SDKEventProperties(
                name: #function,
                params: [
                    "flow": PrimerInternalSessionFlow.checkout.rawValue
                ]))
        
        let connectivityEvent = Analytics.Event(
            eventType: .networkConnectivity,
            properties: NetworkConnectivityEventProperties(
                networkType: Connectivity.networkType))
        
        self.timingEventId = UUID().uuidString
        let timingEvent = Analytics.Event(
            eventType: .timerEvent,
            properties: TimerEventProperties(
                momentType: .start,
                id: self.timingEventId!))
        
        Analytics.Service.record(events: [sdkEvent, connectivityEvent, timingEvent])
        self.show(flow: .default, with: clientToken, completion: completion)
    }
    
    public func showVaultManager(clientToken: String, completion: ((Error?) -> Void)? = nil) {
        checkoutSessionId = UUID().uuidString
        
        let sdkEvent = Analytics.Event(
            eventType: .sdkEvent,
            properties: SDKEventProperties(
                name: #function,
                params: [
                    "flow": PrimerInternalSessionFlow.vault.rawValue
                ]))
        
        let connectivityEvent = Analytics.Event(
            eventType: .networkConnectivity,
            properties: NetworkConnectivityEventProperties(
                networkType: Connectivity.networkType))
        
        self.timingEventId = UUID().uuidString
        let timingEvent = Analytics.Event(
            eventType: .timerEvent,
            properties: TimerEventProperties(
                momentType: .start,
                id: self.timingEventId!))
        
        Analytics.Service.record(events: [sdkEvent, connectivityEvent, timingEvent])
        self.show(flow: .defaultWithVault, with: clientToken)
    }
    
    // swiftlint:disable cyclomatic_complexity
    internal func showPaymentMethod(_ paymentMethod: PrimerPaymentMethodType, withIntent intent: PrimerSessionIntent, andClientToken clientToken: String, completion: ((Error?) -> Void)? = nil) {
        checkoutSessionId = UUID().uuidString
        
        ///
        /// In case of a `nil` paramter being passed to the second value of the tuple, we'll treat that as a checkoutWithAsyncPaymentMethod
        /// 
        let flowIntentPaymentMethods: [PaymentMethodConfigType: (intent: PrimerSessionIntent, flow: PrimerSessionFlow?)] = [
            .adyenAlipay: (.checkout, nil),
            .adyenDotPay: (.checkout, nil),
            .adyenGiropay: (.checkout, nil),
            .adyenIDeal: (.checkout, nil),
            .adyenInterac: (.checkout, nil),
            .adyenMobilePay: (.checkout, nil),
            .adyenPayTrail: (.checkout, nil),
            .adyenSofort: (.checkout, nil),
            .adyenTrustly: (.checkout, nil),
            .adyenTwint: (.checkout, nil),
            .adyenVipps: (.checkout, nil),
            .adyenPayshop: (.checkout, nil),
            .applePay: (.checkout, nil),
            .atome: (.checkout, nil),
            .adyenBlik: (.checkout, nil),
            .buckarooBancontact: (.checkout, nil),
            .buckarooEps: (.checkout, nil),
            .buckarooGiropay: (.checkout, nil),
            .buckarooIdeal: (.checkout, nil),
            .buckarooSofort: (.checkout, nil),
            .coinbase: (.checkout, nil),
            .hoolah: (.checkout, nil),
            .klarna: (.checkout, nil),
            .mollieBankcontact: (.checkout, nil),
            .mollieIdeal: (.checkout, nil),
            .payNLBancontact: (.checkout, nil),
            .payNLGiropay: (.checkout, nil),
            .payNLPayconiq: (.checkout, nil),
            .twoCtwoP: (.checkout, nil),
            .xfers: (.checkout, nil),
            .opennode: (.checkout, nil),
            .payPal: (.checkout, .checkoutWithPayPal),
            .apaya: (.vault, .addApayaToVault),
            .klarna: (.vault, .addKlarnaToVault),
            .paymentCard: (.checkout, .completeDirectCheckout),
            .payPal: (.vault, .addPayPalToVault)
        ]
        
        if let paymentMethod = flowIntentPaymentMethods.first(where: { $0.key == paymentMethod && $0.value.0 == intent }) {
            let sessionFlow = paymentMethod.value.1 ?? .checkoutWithAsyncPaymentMethod(paymentMethodType: paymentMethod.key)
            flow = sessionFlow
        } else {
            let err = PrimerError.unsupportedIntent(intent: intent, userInfo: ["file": #file, "class": "\(Self.self)", "function": #function, "line": "\(#line)"])
            ErrorHandler.handle(error: err)
            PrimerDelegateProxy.primerDidFailWithError(err, data: nil, decisionHandler: { errorDecision in
                switch errorDecision.type {
                case .fail(let message):
                    Primer.shared.primerRootVC?.dismissOrShowResultScreen(type: .failure, withMessage: message)
                }
            })
            return
        }
        
        let sdkEvent = Analytics.Event(
            eventType: .sdkEvent,
            properties: SDKEventProperties(
                name: #function,
                params: [
                    "flow": PrimerInternalSessionFlow.vault.rawValue
                ]))
        
        let connectivityEvent = Analytics.Event(
            eventType: .networkConnectivity,
            properties: NetworkConnectivityEventProperties(
                networkType: Connectivity.networkType))
        
        self.timingEventId = UUID().uuidString
        let timingEvent = Analytics.Event(
            eventType: .timerEvent,
            properties: TimerEventProperties(
                momentType: .start,
                id: self.timingEventId!))
        Analytics.Service.record(events: [sdkEvent, connectivityEvent, timingEvent])
        
        self.show(flow: flow, with: clientToken, completion: completion)
    }
    
    // swiftlint:enable cyclomatic_complexity

    /** Dismisses any opened checkout sheet view. */
    public func dismiss() {
        let sdkEvent = Analytics.Event(
            eventType: .sdkEvent,
            properties: SDKEventProperties(
                name: #function,
                params: nil))
        
        let timingEvent = Analytics.Event(
            eventType: .timerEvent,
            properties: TimerEventProperties(
                momentType: .end,
                id: self.timingEventId))
        
        Analytics.Service.record(events: [sdkEvent, timingEvent])
        
        Analytics.Service.sync()
        
        checkoutSessionId = nil
        flow = nil
        ClientTokenService.resetClientToken()
        
        DispatchQueue.main.async { [weak self] in
            self?.primerRootVC?.dismissPrimerRootViewController(animated: true, completion: {
                self?.primerWindow?.isHidden = true
                if #available(iOS 13, *) {
                    self?.primerWindow?.windowScene = nil
                }
                self?.primerWindow?.rootViewController = nil
                self?.primerRootVC = nil
                self?.primerWindow?.resignKey()
                self?.primerWindow = nil
                PrimerDelegateProxy.primerDidDismiss()
            })
        }
    }
    
    private func show(flow: PrimerSessionFlow, with clientToken: String, completion: ((Error?) -> Void)? = nil) {
        ClientTokenService.storeClientToken(clientToken) { [weak self] error in
            self?.show(flow: flow)
            completion?(error)
        }
    }
    
    private func show(flow: PrimerSessionFlow) {
        self.flow = flow
        
        let event = Analytics.Event(
            eventType: .sdkEvent,
            properties: SDKEventProperties(
                name: #function,
                params: [
                    "flow": flow.internalSessionFlow.rawValue
                ]))
        Analytics.Service.record(event: event)
        
        DispatchQueue.main.async {
            if self.primerRootVC == nil {
                self.primerRootVC = PrimerRootViewController(flow: flow)
            }
            self.presentingViewController = self.primerRootVC
            
            if self.primerWindow == nil {
                if #available(iOS 13.0, *) {
                    if let windowScene = UIApplication.shared.connectedScenes.filter({ $0.activationState == .foregroundActive }).first as? UIWindowScene {
                        self.primerWindow = UIWindow(windowScene: windowScene)
                    } else {
                        // Not opted-in in UISceneDelegate
                        self.primerWindow = UIWindow(frame: UIScreen.main.bounds)
                    }
                } else {
                    // Fallback on earlier versions
                    self.primerWindow = UIWindow(frame: UIScreen.main.bounds)
                }
                
                self.primerWindow!.rootViewController = self.primerRootVC
                self.primerWindow!.backgroundColor = UIColor.clear
                self.primerWindow!.windowLevel = UIWindow.Level.normal
                self.primerWindow!.makeKeyAndVisible()
            }
        }
    }
    
    public func setImplementedReactNativeCallbacks(_ implementedReactNativeCallbacks: ImplementedReactNativeCallbacks) {
        let state: AppStateProtocol = DependencyContainer.resolve()
        state.implementedReactNativeCallbacks = implementedReactNativeCallbacks
    }
    
}

#endif
