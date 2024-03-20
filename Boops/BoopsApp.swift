//
//  BoopsApp.swift
//  Boops
//
//  Created by Terry Yiu on 3/19/24.
//

import SwiftUI
import NostrSDK

@main
struct BoopsApp: App {
    @StateObject var followListFetcher = FollowListFetcher()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(followListFetcher)
        }
    }
}
