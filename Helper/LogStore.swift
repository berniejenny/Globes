//
//  LogStore.swift
//  Eduard
//
//  Created by Bernhard Jenny on 27/10/2023.
//

import Foundation
import SwiftUI

class LogStore: ObservableObject {
    @Published var logMessages: [String] = []

    func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
        }
    }
    
    static let shared = LogStore()
}

struct LogView: View {
    @ObservedObject var logStore = LogStore.shared
         var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack (alignment: .leading) {
                    Text(logStore.logMessages.joined(separator: "\n"))
                        .textSelection(.enabled)
                        .monospaced()
                        .font(Font.system(size: 50))
                        .padding()
                        .id(0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: logStore.logMessages) {
                scrollViewProxy.scrollTo(0, anchor: .bottom)
            }
            .onAppear {
                LogStore.shared.log("Hello, World!")
                LogStore.shared.log("Call LogStore.shared.log() from anywhere in your code.")
                             }
        }
    }
}
