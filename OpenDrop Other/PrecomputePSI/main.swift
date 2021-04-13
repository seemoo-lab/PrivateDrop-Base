//
//  main.swift
//  PrecomputePSI
//
//  Created by Alex - SEEMOO on 23.07.20.
//

import ArgumentParser
import Foundation
import PSI

struct PSIPrecompute: ParsableCommand {
    // MARK: Arguments
    @Flag(
        name: .long,
        help: ArgumentHelp(
            "Verbose logging of all steps", discussion: "", valueName: nil, shouldDisplay: true))
    var verbose: Bool = false

    @Argument(
        help: ArgumentHelp(
            "A list of contact ids",
            discussion:
                """
                A list of contact ids, like email addresses and phone numbers. The list is seperated by spaces.
                The phone numbers do not contain a + sign or 00 they start with the country code: e.g. 471239239
                """, valueName: "Contact ids", shouldDisplay: true))
    var ids: [String] = []

    @Option(
        name: .customLong("sign"), parsing: .next,
        help: ArgumentHelp(
            "Sign Y-values with certificate",
            discussion:
                """
                Provide a certificate to a p12 file that contains the certificate and the private key used for signing
                """, valueName: "Certificate Path", shouldDisplay: true))
    var signingCertPath: String?

    @Option(
        name: .long,
        parsing: .next,
        help: ArgumentHelp(
            "Password for the p12 file",
            discussion: "Optional password for the provided p12 file",
            valueName: "Certificate password",
            shouldDisplay: true))
    var password: String?

    @Option(
        name: .long,
        parsing: .next,
        help: ArgumentHelp(
            "Output directory",
            discussion:
                "Optional output directory to which the generated files should be saved. If not provided the current directory will be used",
            valueName: "Output directoy",
            shouldDisplay: true))
    var output: String?

    var encoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }

    var outputDirectory: String {
        let outputDir: String
        if let output = self.output {
            outputDir = output
        } else {
            outputDir = FileManager.default.currentDirectoryPath
        }
        return outputDir
    }

    init() {}

    // MARK: Code
    func run() throws {
        guard ids.isEmpty == false else {
            log("No contact ids provided. Checkout --help for info", force: true)
            return
        }
        log("Precomputing values for PSI contact ids:\n\(ids)")

        // Initialize PSI
        PSI.initialize(config: .init(useECPointCompression: true))

        let verifier = try Verifier(ids: ids)
        let precomputed = verifier.precompute()

        if let certPath = self.signingCertPath {
            // Sign the precomputed y-values
            log("Generated values. Exporting with signing")
            self.signAndExport(values: precomputed, certPath: certPath)
        } else {
            log("Generated values. Exporting without signing")
            exportUnsigned(values: precomputed)
        }

    }

    func signAndExport(values: VerifierPrecomputed, certPath: String) {
        do {
            let yvalues = YValuesExport(y: values.yValues)
            let yData = try encoder.encode(yvalues)

            // Sign the yData
            let signer = Signer(
                certificatePath: certPath, certificatePassword: self.password, data: yData)
            let cmsMessage = try signer.signCMS()

            // Write to files
            let outputY = URL(fileURLWithPath: self.outputDirectory).appendingPathComponent(
                "yValues.cms")
            try cmsMessage.write(to: outputY)

            let privatePSI = PrivatePSIValues(
                a: values.aValues, hashes: values.hashes, ids: self.ids)
            let psiOutputURL = URL(fileURLWithPath: self.outputDirectory).appendingPathComponent(
                "psiprivate.plist")
            try encoder.encode(privatePSI).write(to: psiOutputURL)

            log("Exported values to \(self.outputDirectory)", force: true)

        } catch {
            log("Exporting failed \(error)", force: true)
        }

    }

    func exportUnsigned(values: VerifierPrecomputed) {
        do {
            // Export as Plist
            let yvalues = YValuesExport(y: values.yValues)
            let outputURL = URL(fileURLWithPath: self.outputDirectory).appendingPathComponent(
                "yValues.plist")
            try encoder.encode(yvalues).write(to: outputURL)

            let privatePSI = PrivatePSIValues(
                a: values.aValues, hashes: values.hashes, ids: self.ids)
            let psiOutputURL = URL(fileURLWithPath: self.outputDirectory).appendingPathComponent(
                "psiprivate.plist")
            try encoder.encode(privatePSI).write(to: psiOutputURL)

            log("Exported values to \(self.outputDirectory)", force: true)
        } catch {
            log("Exporting failed \(error)", force: true)
        }
    }

    func log(_ info: String, force: Bool = false) {
        guard verbose || force else { return }
        print(info)
    }
}

PSIPrecompute.main()

struct YValuesExport: Codable {
    let y: [Data]
}

struct PrivatePSIValues: Codable {
    let a: [Data]
    let hashes: [Data]
    let ids: [String]
}
