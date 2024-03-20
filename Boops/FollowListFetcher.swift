//
//  FollowListFetcher.swift
//  Boops
//
//  Created by Terry Yiu on 3/19/24.
//

import Foundation
import NostrSDK
import Combine

class FollowListFetcher: ObservableObject {
    @Published var followListEvent: FollowListEvent? = nil

    var relayPool = try! RelayPool(relayURLs: [
        URL(string: "wss://relay.damus.io")!,
        URL(string: "wss://relay.primal.net")!,
        URL(string: "wss://relay.snort.social")!,
    ])

    private var pubkey: PublicKey? = nil
    private var subscriptionId: String? = nil
    private var eventsCancellable: AnyCancellable? = nil

    private var followListFilter: Filter? {
        guard let pubkey else {
            return nil
        }

        return Filter(authors: [pubkey.hex], kinds: [EventKind.followList.rawValue])
    }

    func updatePubkey(_ pubkey: String) {
        if let eventsCancellable {
            eventsCancellable.cancel()
        }

        if let subscriptionId {
            relayPool.closeSubscription(with: subscriptionId)
            self.subscriptionId = nil
        }

        followListEvent = nil

        self.pubkey = PublicKey(hex: pubkey)
        print(self.pubkey?.hex ?? "could not create public key with hex \(pubkey)")
    }

    func fetch() {
        guard let followListFilter, subscriptionId == nil else {
            return
        }

        if let eventsCancellable {
            eventsCancellable.cancel()
        }

        relayPool.connect()

        subscriptionId = relayPool.subscribe(with: followListFilter)

        eventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .compactMap {
                $0.event as? FollowListEvent
            }
            .removeDuplicates()
            .sink { event in
                if let followListEvent = self.followListEvent {
                    if followListEvent.createdAt < event.createdAt {
                        self.followListEvent = event
                    }
                } else {
                    self.followListEvent = event
                }
            }
    }
}
