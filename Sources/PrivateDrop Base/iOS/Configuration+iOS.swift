//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation

#if canImport(UIKit)
    import UIKit

    extension PrivateDrop.Configuration {
        static func currentComputerName() -> String? {
            return UIDevice.current.name
        }

        static func currentModel() -> String? {
            var systemInfo = utsname()
            uname(&systemInfo)
            let modelCode = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                    String.init(validatingUTF8: ptr)
                }
            }
            return modelCode
        }
    }
#endif
