//
//  BundleExtension.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 24.07.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation

extension Bundle {
    static var privateDrop: Bundle {
        return Bundle(for: PrivateDrop.self)
    }

    var caURL: URL {
        return self.url(forResource: "OpenDrop-PSI-Sign-3", withExtension: "pem")!
    }
}
