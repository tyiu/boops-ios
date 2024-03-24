//
//  ContentView.swift
//  Boops
//
//  Created by Terry Yiu on 3/19/24.
//

import SwiftUI
import NostrSDK

struct ContentView: View {
    @EnvironmentObject var nostrEventManager: NostrEventManager
    @State private var authorPubkey: String = ""

    var body: some View {
        Form {
            Section("Query Relays") {
                TextField(text: $authorPubkey) {
                    Text("Author Public Key (HEX)")
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }

            Button {
                nostrEventManager.updatePubkey(authorPubkey)
                nostrEventManager.fetchFollowLists()
            } label: {
                Text("Query")
                    .disabled(authorPubkey.isEmpty)
            }

            Section("Follow List") {
                List {
                    if let followListEvent = nostrEventManager.followListEvent {
                        ForEach(followListEvent.followedPubkeys, id: \.self) { followedPubkey in
                            if let userMetadata = nostrEventManager.metadataEvents[followedPubkey]?.userMetadata {
                                HStack {
                                    if let pictureURL = userMetadata.pictureURL {
                                        AsyncImage(url: pictureURL) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: 100, maxHeight: 100)
                                        } placeholder: {
                                            ProgressView()
                                        }
                                    }

                                    Text(userDisplayName(pubkey: followedPubkey, userMetadata: userMetadata))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if let followedReactionEvent = nostrEventManager.reactionEvents[followedPubkey] {
                                        if followedReactionEvent.pubkey == authorPubkey {
                                            Button {

                                            } label: {
                                                Text("Booped")
                                            }
                                            .frame(alignment: .trailing)
                                            .buttonStyle(.bordered)
                                        } else {
                                            Button {

                                            } label: {
                                                Text("Boop Back")
                                            }
                                            .frame(alignment: .trailing)
                                            .buttonStyle(.bordered)
                                        }
                                    } else {
                                        Button {

                                        } label: {
                                            Text("👉 Boop")
                                        }
                                        .frame(alignment: .trailing)
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func userDisplayName(pubkey: String, userMetadata: UserMetadata) -> String {
        if let displayName = userMetadata.displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }

        if let name = userMetadata.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        if let nostrAddress = userMetadata.nostrAddress, !nostrAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nostrAddress
        }

        return pubkey
    }
}

#Preview {
    ContentView()
}
