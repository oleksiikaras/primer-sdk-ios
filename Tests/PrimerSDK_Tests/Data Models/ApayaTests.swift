//
//  ApayaTests.swift
//  PrimerSDK_Tests
//
//  Created by Carl Eriksson on 01/08/2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

#if canImport(UIKit)

import XCTest
@testable import PrimerSDK

class ApayaDataModelTests: XCTestCase {
    
    let rootUrl = "https://primer.io/apaya/result?"
    
    func test_apaya_web_view_result_created_from_correct_url() throws {
        let url = URL(string: rootUrl + "token=A9IotQFdJBSYjth7h)hGWmFAgzVjxU6xeGGT)AaAbB=&pt=ExamplePTValue&success=1&status=SETUP_SUCCESS&HashedIdentifier=602&MX=MX&MCC=208&MNC=91&success=1")
        
        let state: AppStateProtocol = MockAppState()
        state.paymentMethodConfig = mockPaymentMethodConfig
        DependencyContainer.register(state as AppStateProtocol)
        let settings = PrimerSettings(currency: .GBP)
        DependencyContainer.register(settings as PrimerSettingsProtocol)
        
        let result = Apaya.WebViewResult.create(from: url)
        switch result {
        case .success(let value):
            XCTAssertEqual(value.success, "1")
        case .failure:
            XCTFail()
        }
    }
    
    func test_apaya_web_view_result_fails_on_success_not_provided() throws {
        let url = URL(string: rootUrl + "pt=ExamplePTValue&status=SETUP_SUCCESS&HashedIdentifier=602&MX=MX&MCC=208&MNC=91")
        
        let state: AppStateProtocol = MockAppState()
        state.paymentMethodConfig = mockPaymentMethodConfig
        DependencyContainer.register(state as AppStateProtocol)
        let settings = PrimerSettings(currency: .GBP)
        DependencyContainer.register(settings as PrimerSettingsProtocol)
        
        let result = Apaya.WebViewResult.create(from: url)
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    func test_apaya_web_view_result_fails_on_invalid_url() throws {
        let url = URL(string: "")
        let result = Apaya.WebViewResult.create(from: url)
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    func test_apaya_web_view_result_fails_on_error_url() throws {
        let url = URL(string: rootUrl + "success=0&status=SETUP_ERROR")
        let result = Apaya.WebViewResult.create(from: url)
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            XCTAssertNotNil(error)
        }
    }
    
    func test_apaya_web_view_result_nil_on_cancel_url() throws {
        let url = URL(string: rootUrl + "success=0&status=SETUP_ABANDONED")
        let result = Apaya.WebViewResult.create(from: url)
        switch result {
        case .success:
            XCTFail()
        case .failure(let err):
            if let apayaErr = err as? ApayaException, apayaErr == .webViewFlowCancelled {
                
            } else {
                XCTFail("Error should be .webViewFlowCancelled")
            }
        }
    }
    
    func test_apaya_carrier() throws {
        var carrier: Apaya.Carrier!
        
        carrier = Apaya.Carrier(mcc: 234, mnc: 99)
        if carrier != Apaya.Carrier.EE_UK {
            XCTFail("Wrong carrier")
        }
        
        carrier = Apaya.Carrier(mcc: 234, mnc: 11)
        if carrier != Apaya.Carrier.O2_UK {
            XCTFail("Wrong carrier")
        }
        
        carrier = Apaya.Carrier(mcc: 234, mnc: 15)
        if carrier != Apaya.Carrier.Vodafone_UK {
            XCTFail("Wrong carrier")
        }
        
        carrier = Apaya.Carrier(mcc: 234, mnc: 20)
        if carrier != Apaya.Carrier.Three_UK {
            XCTFail("Wrong carrier")
        }
        
        carrier = Apaya.Carrier(mcc: 242, mnc: 99)
        if carrier != Apaya.Carrier.Strex_Norway {
            XCTFail("Wrong carrier")
        }
    }
    
}


#endif