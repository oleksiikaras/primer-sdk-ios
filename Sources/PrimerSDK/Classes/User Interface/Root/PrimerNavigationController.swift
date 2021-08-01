//
//  PrimerNavigationController.swift
//  PrimerSDK
//
//  Created by Evangelos Pittas on 30/7/21.
//

import UIKit

/// UINavigationController subclass that intercepts pop, and handles it through the PrimerRootViewController
class PrimerNavigationController: UINavigationController, UINavigationBarDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.barTintColor = .green
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.orange]
        navigationBar.backItem?.backBarButtonItem?.tintColor = .orange
    }
    
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        Primer.shared.primerRootVC.popViewController()
        return false
    }
}
