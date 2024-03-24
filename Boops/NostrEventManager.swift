//
//  NostrEventManager.swift
//  Boops
//
//  Created by Terry Yiu on 3/19/24.
//

import Foundation
import NostrSDK
import Combine

class NostrEventManager: ObservableObject {
    @Published var followListEvent: FollowListEvent? = nil

    var relayPool = try! RelayPool(relayURLs: [
//        URL(string: "wss://relay.damus.io")!,
        URL(string: "wss://relay.primal.net")!,
//        URL(string: "wss://relay.snort.social")!,
    ])

    private var pubkey: PublicKey? = nil

    private var followListSubscriptionId: String? = nil
    private var followListEventsCancellable: AnyCancellable? = nil

    @Published var metadataEvents = [String : SetMetadataEvent]()
    private var metadataEventsSubscriptionId: String? = nil
    private var metadataEventsCancellable: AnyCancellable? = nil

    @Published var reactionEvents = [String : ReactionEvent]()
    private var followedReactionEventsSubscriptionId: String? = nil
    private var followedReactionEventsCancellable: AnyCancellable? = nil
    private var ownReactionEventsSubscriptionId: String? = nil
    private var ownReactionEventsCancellable: AnyCancellable? = nil

    private var followListFilter: Filter? {
        guard let pubkey else {
            return nil
        }

        return Filter(authors: [pubkey.hex], kinds: [EventKind.followList.rawValue], limit: 1)
    }

    private func metadataFilter(_ followedPubkeys: Set<String>) -> Filter? {
        guard pubkey != nil else {
            return nil
        }

        let missingPubkeys = followedPubkeys.subtracting(metadataEvents.keys)

        guard !missingPubkeys.isEmpty else {
            return nil
        }

        return Filter(authors: Array(missingPubkeys), kinds: [EventKind.setMetadata.rawValue])
    }

    private func ownReactionsFilter(_ followedPubkeys: Set<String>) -> Filter? {
        guard let pubkey else {
            return nil
        }

        return Filter(authors: [pubkey.hex], kinds: [EventKind.reaction.rawValue], pubkeys: Array(followedPubkeys))
    }

    private func followedReactionsFilter(_ followedPubkeys: Set<String>) -> Filter? {
        guard let pubkey else {
            return nil
        }

        return Filter(authors: Array(followedPubkeys), kinds: [EventKind.reaction.rawValue], pubkeys: [pubkey.hex])
    }

    func updatePubkey(_ pubkey: String) {
        if let followListEventsCancellable {
            followListEventsCancellable.cancel()
        }
        if let metadataEventsCancellable {
            metadataEventsCancellable.cancel()
        }
        if let followedReactionEventsCancellable {
            followedReactionEventsCancellable.cancel()
        }
        if let ownReactionEventsCancellable {
            ownReactionEventsCancellable.cancel()
        }

        if let followListSubscriptionId {
            relayPool.closeSubscription(with: followListSubscriptionId)
            self.followListSubscriptionId = nil
        }
        if let metadataEventsSubscriptionId {
            relayPool.closeSubscription(with: metadataEventsSubscriptionId)
            self.metadataEventsSubscriptionId = nil
        }
        if let followedReactionEventsSubscriptionId {
            relayPool.closeSubscription(with: followedReactionEventsSubscriptionId)
            self.followedReactionEventsSubscriptionId = nil
        }
        if let ownReactionEventsSubscriptionId {
            relayPool.closeSubscription(with: ownReactionEventsSubscriptionId)
            self.ownReactionEventsSubscriptionId = nil
        }

        followListEvent = nil
        reactionEvents.removeAll()

        self.pubkey = PublicKey(hex: pubkey)
        print(self.pubkey?.hex ?? "could not create public key with hex \(pubkey)")

        relayPool.connect()
    }

    func fetchFollowLists() {
        guard let pubkey, let followListFilter, followListSubscriptionId == nil else {
            return
        }

        if let followListEventsCancellable {
            followListEventsCancellable.cancel()
        }

        followListSubscriptionId = relayPool.subscribe(with: followListFilter)

        followListEventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard let followListEvent = event.event as? FollowListEvent, followListEvent.pubkey == pubkey.hex else {
                    return
                }

                if let existingFollowListEvent = self.followListEvent {
                    if existingFollowListEvent.createdAt < followListEvent.createdAt {
                        self.followListEvent = followListEvent
                        self.fetchMetadata(followListEvent.followedPubkeys)
                        self.fetchOwnReactions(followListEvent.followedPubkeys)
                        self.fetchFollowedReactions(followListEvent.followedPubkeys)
                    }
                } else {
                    self.followListEvent = followListEvent
                    self.fetchMetadata(followListEvent.followedPubkeys)
                    self.fetchOwnReactions(followListEvent.followedPubkeys)
                    self.fetchFollowedReactions(followListEvent.followedPubkeys)
                }
            }
    }

    func fetchMetadata(_ pubkeys: [String]) {
        guard pubkey != nil, let filter = metadataFilter(Set(pubkeys)), metadataEventsSubscriptionId == nil else {
            return
        }

        if let metadataEventsCancellable {
            metadataEventsCancellable.cancel()
        }

        metadataEventsSubscriptionId = relayPool.subscribe(with: filter)

        metadataEventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard let metadataEvent = event.event as? SetMetadataEvent else {
                    return
                }

                if let existingMetadataEvent = self.metadataEvents[metadataEvent.pubkey] {
                    if existingMetadataEvent.createdAt < metadataEvent.createdAt {
                        self.metadataEvents[metadataEvent.pubkey] = metadataEvent
                    }
                } else {
                    self.metadataEvents[metadataEvent.pubkey] = metadataEvent
                }
            }
    }

    func fetchFollowedReactions(_ pubkeys: [String]) {
        guard let pubkey, let filter = followedReactionsFilter(Set(pubkeys)), followedReactionEventsSubscriptionId == nil else {
            return
        }

        if let followedReactionEventsCancellable {
            followedReactionEventsCancellable.cancel()
        }

        followedReactionEventsSubscriptionId = relayPool.subscribe(with: filter)

        followedReactionEventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard let reactionEvent = event.event as? ReactionEvent, reactionEvent.reactedEventPubkey == pubkey.hex else {
                    return
                }

                if let existingReactionEvent = self.reactionEvents[reactionEvent.pubkey] {
                    if existingReactionEvent.createdAt < reactionEvent.createdAt {
                        self.reactionEvents[reactionEvent.pubkey] = reactionEvent
                    }
                } else {
                    self.reactionEvents[reactionEvent.pubkey] = reactionEvent
                }
            }
    }

    func fetchOwnReactions(_ pubkeys: [String]) {
        guard let pubkey, let filter = ownReactionsFilter(Set(pubkeys)), ownReactionEventsSubscriptionId == nil else {
            return
        }

        if let ownReactionEventsCancellable {
            ownReactionEventsCancellable.cancel()
        }

        ownReactionEventsSubscriptionId = relayPool.subscribe(with: filter)

        ownReactionEventsCancellable = relayPool.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard let reactionEvent = event.event as? ReactionEvent, let reactedEventPubkey = reactionEvent.reactedEventPubkey, reactionEvent.pubkey == pubkey.hex else {
                    return
                }

                if let existingReactionEvent = self.reactionEvents[reactedEventPubkey] {
                    if existingReactionEvent.createdAt < reactionEvent.createdAt {
                        self.reactionEvents[reactedEventPubkey] = reactionEvent
                    }
                } else {
                    self.reactionEvents[reactedEventPubkey] = reactionEvent
                }
            }
    }
}
