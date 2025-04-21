//
//  PESoftPOSApp.swift
//  PESoftPOS
//
//  Created by Rashid Kamran on 4/16/25.
//

import SwiftUI

func log(_ message: String){
    print("PESoftPOS :: \(message)")
}

@main
struct PESoftPOSApp: App {
    
    var body: some Scene {
        WindowGroup {
            SampleView()
        }
    }
}
