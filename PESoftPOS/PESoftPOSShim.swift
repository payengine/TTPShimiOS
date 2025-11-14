//
//  PESoftPOSShim.swift
//  PEDevicePaymentSampleSwift

import Foundation
import PEDevicePaymentSDK



func printlog(_ message: String){
#if DEBUG
    print("PETapToPayShim :: \(message)")
#endif
}


/// Errors surfaced by the shim layer
enum PETapError: Error {
    case initializationFailed(Error)
    case connectionFailed(Error)
    case transactionFailed(PEPaymentResult)
    case noAvailableDevice
    case activationRequired(String)
}


// MARK: -
/// Async entrypoint to initialize & (optionally) auto‑connect
class PETapToPayShim {
    
    fileprivate static var initializationDelegate: SDKInitializationDelegate?
    fileprivate static var deviceDelegate: DeviceDelegate?
    
    static var terminalInfo: TerminalInfo? = nil
    
    static let peSDK: PEPaymentDevice = {
        let peSDK = PEPaymentDevice.shared
        PEPaymentDevice.environment = PEEnvironment.Sandbox
        return peSDK
    }()
    
    
    static func getActivationCode() async throws -> String? {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            printlog("Inside initializeDevice")
            initializationDelegate = SDKInitializationDelegate(activationCodeCont: cont)
            peSDK.initialize(delegate: initializationDelegate!)
        }
        
    }
    
    static func isActivated( ) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
            printlog("Inside initializeDevice")
            initializationDelegate = SDKInitializationDelegate(activationCheckCont: cont)
            peSDK.initialize(delegate: initializationDelegate!)
        }
        
    }
    
    /// Initialize the device; if autoConnect is true, will also connect automatically.
    @discardableResult static func initializeDevice( mode: TransactionMode = .device,
                                                     autoConnect: Bool = true ) async throws -> PEDevice {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PEDevice, Error>) in
            printlog("Inside initializeDevice")
            initializationDelegate = SDKInitializationDelegate(autoConnect: autoConnect, continuation: continuation)
            peSDK.initialize(delegate: initializationDelegate!)
        }
    }
    
    /// Start a payment and await its result
    static func startTransaction(request: PEPaymentRequest) async throws -> PEPaymentResult {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PEPaymentResult, Error>) in
            printlog("Inside startTransaction")
            if let deviceDelegate = self.deviceDelegate {
                deviceDelegate.txnContinue = cont
            }
            self.peSDK.startTransaction(request: request, transactionResultViewController: .init(onDismissed: {
                print("Authorization screen dismissed")
            }))
        }
    }
    
    static func deinitialize() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if let initializationDelegate = self.initializationDelegate {
                initializationDelegate.deinitializationContinuation = cont
            }
            
            peSDK.deinitialize()
        }
    }
}


// MARK: - SDKInitializationDelegate
private class SDKInitializationDelegate: PEInitializationDelegate {
    
    let autoConnect: Bool
    var continuation: CheckedContinuation<PEDevice, Error>? = nil
    var activationCheckContinuation: CheckedContinuation<Bool, Error>? = nil
    var activationCodeContinuation: CheckedContinuation<String, Error>? = nil
    var deinitializationContinuation: CheckedContinuation<Void, Never>? = nil
    
    init( autoConnect: Bool = true,
          continuation: CheckedContinuation<PEDevice, Error>? = nil,
          activationCheckCont: CheckedContinuation<Bool, Error>? = nil,
          activationCodeCont: CheckedContinuation<String, Error>? = nil,
          deinitializationCont: CheckedContinuation<Void, Never>? = nil
    ) {
        
        self.autoConnect = autoConnect
        self.activationCodeContinuation = activationCodeCont
        self.activationCheckContinuation = activationCheckCont
        self.continuation = continuation
        self.deinitializationContinuation = deinitializationCont
    }
    
    func onInitFailed(error: Error) {
        self.activationCheckContinuation?.resume(throwing: error)
        self.continuation?.resume(throwing: error)
        
        
        self.activationCheckContinuation = nil
        self.continuation = nil
    }
    
    func onInitialized(availableDevices: [PEDevice]) {
        
        if let activationCheckContinuation = activationCheckContinuation {
            activationCheckContinuation.resume(returning: true)
            continuation = nil
            self.activationCheckContinuation = nil
            activationCodeContinuation = nil
            
            return
        }
        
        
        guard let _ = availableDevices.first  else {
            continuation?.resume(throwing: PETapError.noAvailableDevice)
            continuation = nil
            activationCheckContinuation = nil
            activationCodeContinuation = nil
            
            return
        }
        
        PETapToPayShim.deviceDelegate = DeviceDelegate(cont: continuation)
        PEPaymentDevice.shared.connect(delegate: PETapToPayShim.deviceDelegate!)
    }
    
    // no‑ops
    func didLaunchEducationalScreen() {}
    func willLaunchEducationalScreen() {}
    
    func onActivationRequired(activationCode: String) {
        
        activationCheckContinuation?.resume(returning: false)
        activationCodeContinuation?.resume(returning : activationCode)
        
        continuation = nil
        activationCheckContinuation = nil
        activationCodeContinuation = nil
        
    }
    func onActivationStarting(terminalInfo: TerminalInfo) {
        PETapToPayShim.terminalInfo = terminalInfo
    }
    func onEducationScreenDismissed() {}
    
    func onDeinitialized() {
        self.deinitializationContinuation?.resume()
        self.deinitializationContinuation = nil
    }
}


// MARK: - Device Delegate
class DeviceDelegate: PEDeviceDelegate {
    var cont: CheckedContinuation<PEDevice, Error>? = nil
    var txnContinue: CheckedContinuation<PEPaymentResult, Error>? = nil
    
    init(cont: CheckedContinuation<PEDevice, Error>?) {
        self.cont = cont
    }
    
    func onConnected(device: PEDevice) {
        printlog("I am here in onConnected")
        cont?.resume(returning: device)
        cont = nil
    }
    
    func onConnectionFailed(device: PEDevice, error: Error) {
        printlog("I am here in onConnectionFailed")
        cont?.resume(throwing: error)
        cont = nil
    }
    
    // required stubs
    func onDeviceDiscovered(_ device: DiscoverableDevice) {}
    func onDeviceSelected(device: PEDevice) {
        printlog("I am here in onDeviceDiscovered")
    }
    func onDiscoveringDevice(_ discovering: Bool) {
        printlog("I am here in onDiscoveringDevice")
    }
    func onLcdConfirmation(_ text: String) {}
    func onLcdMessage(_ text: String) {}
    func didStartAuthorization(_ request: PEPaymentRequest) {}
    func didStartTransaction(_ request: PEPaymentRequest) {
        printlog("I am here in didStartTransaction")
    }
    func onActivationProgress(device: PEDevice, completed: Int) {
        printlog("I am here in onActivationProgress")
    }
    func onCardRead(success: Bool) {}
    
    func onTransactionCompleted(transaction: PEPaymentResult) {
        if let txnContinue = self.txnContinue{
            txnContinue.resume(returning: transaction)
        }
        self.txnContinue = nil
    }
    
    func onTransactionFailed(transaction: PEPaymentResult) {
        if let txnContinue = self.txnContinue{
            txnContinue.resume(throwing: PETapError.transactionFailed(transaction))
        }
        self.txnContinue = nil
    }
}

