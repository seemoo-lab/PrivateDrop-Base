//
//  PrivateDropTestDelegate.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 27.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation

public protocol PrivateDropTestDelegate: AnyObject {

    // PSI
    func startCalculatingZ()

    func calculatedZ()

    func startCalculatingPOK()

    func calculatedPOK()

    func startVerifying()

    func verified()

    func startCalculatingV()

    func calculatedV()

    func startIntersecting()

    func intersected()

    func PSICompleted(peerContacts: Int, peerIds: Int)

    func authenticationFinished()

    func precomputeUDuration(time: TimeInterval)

    func precomputeContactHashesDuration(time: TimeInterval)

    // Sender

    func startedBrowsing()

    func sendingPSIStart()

    func receivedPSIStartResponse()

    func actuallySendingPSIStart()

    func sendingPSIFinish()

    func actuallySendingPSIFinish()

    func receivedPSIFinish()

    func sendingDiscoverRequest()

    func actuallySendingDiscoverRequest()

    func receivedDiscoverResponse()

    func startsSendingFile()

    /// Finished sending with given payload size
    /// - Parameter payloadSize: Payload size in bytes (after archiving)
    func fileSent(payloadSize: Int)

    // Receiver

    func psiStartReceived()

    func psiStartSentResponseSent()

    func psiFinishReceived()

    func psiFinishResponseSent()

    func discoverReceived()

    func discoverResponseSent()

    /// Received upload with payload size in bytes
    /// - Parameter size: Payload Size in bytes (before the file is unarchived)
    func fileReceived(size: Int)

}
