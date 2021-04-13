//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation

#if canImport(IOKit) && canImport(AppKit)
    import IOKit
    import AppKit

    extension PrivateDrop.Configuration {
        static func currentComputerName() -> String? {
            return Host.current().name
        }

        static func currentModel() -> String? {
            let service = IOServiceGetMatchingService(
                kIOMasterPortDefault,
                IOServiceMatching("IOPlatformExpertDevice"))
            var modelIdentifier: String?

            if let modelData = IORegistryEntryCreateCFProperty(
                service, "model" as CFString, kCFAllocatorDefault, 0
            ).takeRetainedValue() as? Data {
                if let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(
                    using: .utf8)
                {
                    modelIdentifier = String(cString: modelIdentifierCString)
                }
            }

            IOObjectRelease(service)
            return modelIdentifier
        }
    }
#endif
