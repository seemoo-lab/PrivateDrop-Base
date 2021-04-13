//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation

enum AirDropFlags: UInt8 {
    case supportsURL = 0x01
    case supportsDVZIP = 0x03
    case supportPipelining = 0x04
    case supportsMixedTypes = 0x08
    case supportsUnknown1 = 0x10
    case supportsUnknown2 = 0x20
    case supportsIRIS = 0x40
    case supportsDiscover = 0x80
    case supportsPSI = 0xe0
}
