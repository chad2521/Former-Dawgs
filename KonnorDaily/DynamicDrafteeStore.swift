import Foundation

extension DynamicDrafteeStore {
    @discardableResult
    static func upsert(_ picks: [DraftPickResult]) -> [DynamicDraftee] {
        var existing = loadAll()
        let existingIDs = Set(existing.map(\.id))
        let staticIDs = Set(PlayerCatalog.staticPlayers.map(\.id))

        var newlyAdded: [DynamicDraftee] = []
        for pick in picks where !existingIDs.contains(pick.id) && !staticIDs.contains(pick.id) && !PlayerCatalog.excludedPlayerIDs.contains(pick.id) {
            let entry = DynamicDraftee.from(pick)
            existing.append(entry)
            newlyAdded.append(entry)
        }

        existing.sort { $0.discoveredAt < $1.discoveredAt }
        save(existing)
        return newlyAdded
    }
}

extension DynamicDraftee {
    static func from(_ pick: DraftPickResult) -> DynamicDraftee {
        DynamicDraftee(
            id: pick.id,
            fullName: pick.fullName,
            role: pick.role,
            kindRawValue: pick.kind.rawValue,
            pickOverall: pick.pickOverall,
            pickRound: pick.pickRound,
            teamID: pick.teamID,
            teamName: pick.teamName,
            teamLogoCode: pick.teamLogoCode,
            draftYear: pick.draftYear,
            discoveredAt: Date()
        )
    }
}
