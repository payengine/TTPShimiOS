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
    @State private var inProgress = false
    
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
            .disabled(self.transactionAmount.isEmpty || self.inProgress)
            
            Text(resultMessage)
                .foregroundColor(.blue)
                .padding(.top, 10)
                .lineLimit(6)
            
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
        self.inProgress = true
        
        Task {
            do {
                guard try await PETapToPayShim.isActivated() else {
                    // Not activated - Get activatoin code
                    let activationCode = try await PETapToPayShim.getActivationCode()
                    let activationCodeMessage = "Activation code: \(activationCode ?? "NO CODE")"
                    self.resultMessage = activationCodeMessage
                    self.inProgress = false
                    print(activationCodeMessage)
                    return
                }
                
                // Step 1 - initialize SDK
                try await PETapToPayShim.initializeDevice()
                
                // Step 2 - Prepare and run transaction
                if let decimalAmount = Decimal(string: transactionAmount) {
                    let req = PEPaymentRequest(transactionAmount: decimalAmount,
                                               transactionData: PEJSON([
                                                    "transactionMonitoringBypass": true, // To bypass monitoring rules
                                                    "data": [
                                                       "sales_tax": 1.25, // Level 2 data example
                                                       "order_number": "XXX12345", // Level 2 data example
                                                       "gateway_id": "cea013fd-ac46-4e47-a2dc-a1bc3d89bf0c" // Route to specific gateway - Change it to valid gateway ID
                                                    ]
                                                ]),
                                               currencyCode: "USD")
                    
                    let transactionResult = try await PETapToPayShim.startTransaction(request: req)
                    let transactionSucceededMessage = "Transaction completed: \(transactionResult.isSuccess)\nTransactionID: \(transactionResult.transactionId ?? "")\nresponseMessage: \(transactionResult.responseMessage ?? "")"
                    
                    self.resultMessage = transactionSucceededMessage
                    print(transactionSucceededMessage)
                }
                
                await PETapToPayShim.deinitialize()
                
                print("✅ Transaction succeeded")
                
                self.inProgress = false
            } catch PETapError.transactionFailed(let transactionResult) {
                self.errorMessage = transactionResult.error?.localizedDescription ?? "Unknown error"
                self.inProgress = false
            }
            catch {
                await PETapToPayShim.deinitialize()
                print("❌ PayEngine flow failed:", error)
                self.errorMessage = error.localizedDescription
                self.inProgress = false
            }
        }
    }
}
