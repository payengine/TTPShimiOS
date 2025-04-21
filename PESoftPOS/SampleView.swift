//
//  ShimTestView.swift
//  PEDevicePaymentSampleSwift
//
//  Created by Saim Irfan on 21/04/2025.
//

import SwiftUI
import PEDevicePaymentSDK

struct SampleView: View {
    @State private var transactionAmount: String = ""
    @State private var resultMessage: String = ""
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            TextField("Enter decimal value", text: $transactionAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: transactionAmount) { oldValue, newValue in
                    self.resultMessage = ""
                    self.errorMessage = ""
                }
            
            Button("Start Transaction") {
                self.resultMessage = ""
                self.errorMessage = ""
                self.startTransaction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(transactionAmount.isEmpty)
            
            Text(resultMessage)
                .foregroundColor(.blue)
                .padding(.top, 10)
            
            Text(errorMessage)
                .foregroundStyle(.red)
                .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Shim Test")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Run transaction method
    private func startTransaction() {
        Task {
            do {
                guard try await PETapToPayShim.isActivated() else {
                    // Not activated - Get activatoin code
                    let activationCode = try await PETapToPayShim.getActivationCode()
                    let activationCodeMessage = "Activation code: \(activationCode ?? "NO CODE")"
                    self.resultMessage = activationCodeMessage
                    print(activationCodeMessage)
                    return
                }
                
                try await PETapToPayShim.initializeDevice(mode: .device, autoConnect: true)
                
                if let decimalAmount = Decimal(string: transactionAmount) {
                    let req = PEPaymentRequest(transactionAmount: decimalAmount, currencyCode: "USD")
                    
                    let transactionResult = try await PETapToPayShim.startTransaction(request: req)
                    let transactionSucceededMessage = "Transaction complete: \(transactionResult.isSuccess) - transactionID: \(String(describing: transactionResult.transactionId)) - responseCode: \(String(describing: transactionResult.responseCode)) - responseMessage: \(String(describing: transactionResult.responseMessage))"
                    
                    self.resultMessage = transactionSucceededMessage
                    print(transactionSucceededMessage)
                }
                
                await PETapToPayShim.deinitialize()
                
                print("✅ Transaction succeeded")
                
            } catch PETapError.transactionFailed(let transactionResult) {
                self.errorMessage = transactionResult.error?.localizedDescription ?? "Unknown error"
            }
            catch {
                await PETapToPayShim.deinitialize()
                print("❌ PayEngine flow failed:", error)
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
