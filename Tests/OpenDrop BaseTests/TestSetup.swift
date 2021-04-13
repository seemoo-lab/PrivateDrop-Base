//
//  TestSetup.swift
//  PrivateDrop BaseTests
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation

struct TestSetup {
    // MARK: - Generation

    static func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    static func generateRandomTestSet(of size: Int) -> [String] {
        var testSet = [String]()

        for _ in 0..<size {
            testSet.append(randomString(length: 15))
        }

        return testSet
    }
}
