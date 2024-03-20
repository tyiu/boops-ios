//
//  ContentView.swift
//  Boops
//
//  Created by Terry Yiu on 3/19/24.
//

import SwiftUI
import NostrSDK

struct ContentView: View {
    @EnvironmentObject var followListFetcher: FollowListFetcher
    @State private var authorPubkey: String = ""

    var body: some View {
        Form {
            Section("Query Relays") {
                TextField(text: $authorPubkey) {
                    Text("Author Public Key (HEX)")
                }
            }

            Button {
                followListFetcher.updatePubkey(authorPubkey)
                followListFetcher.fetch()
            } label: {
                Text("Query")
            }

            Section("Follow List") {
                List {
                    if let followListEvent = followListFetcher.followListEvent {
                        ForEach(followListEvent.followedPubkeys, id: \.self) { followedPubkey in
                            Text(followedPubkey)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
