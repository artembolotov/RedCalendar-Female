//
//  SyncStorage.swift
//  RedCalendar-Female
//

import Foundation

/// The `sync_state` row (SYNC.md §3.1), as a sync run reads it.
///
/// `local_seq` is not here on purpose. It is bumped and read inside the very transaction that
/// stamps a row (`DatabaseService.upsertStamped`), and a copy handed out to a caller would be
/// stale by definition — the same staleness §5.4 rules out for `sent_max`.
struct LocalSyncState: Sendable, Equatable {
    /// The database's owner. `nil` on a v3.2 upgrade and until the first response names one,
    /// which is what makes that first run pull-only (§5.2).
    var userId: String?
    var cursor: Int
    var importStatus: String?
}

/// Everything a run may push, plus the generation it is pushing (§5.1 step 3).
///
/// `sentMax` is the maximum `dirty_seq` **over the rows actually read**, computed in the same
/// transaction that read them. Asked for separately it would count an edit made in between as
/// sent, and clear its flag on the way back — which is the one loss the whole column exists to
/// prevent (§5.4).
struct DirtyBatch: Sendable {
    var cycles: [CycleRecord] = []
    var flowLevels: [FlowLevelRecord] = []
    var comments: [CommentRecord] = []
    var userTags: [UserTagRecord] = []
    var dayTags: [DayTagsRecord] = []
    var profile: UserProfileRecord?
    /// `nil` when nothing was dirty — not zero. Zero would read as "everything at or below
    /// generation 0 was sent", which is a statement about no rows but is one step from the
    /// statement about all of them that §5.1 spends a paragraph forbidding.
    var sentMax: Int?

    /// What actually goes on the wire — and what "empty" is judged on, since the server counts
    /// rows rather than keys (§4.3).
    var push: SyncChangesPush {
        SyncChangesPush(
            cycles: cycles.map(SyncCycleRow.init),
            flowLevels: flowLevels.map(SyncFlowLevelRow.init),
            comments: comments.map(SyncCommentRow.init),
            userTags: userTags.map(SyncUserTagRow.init),
            dayTags: dayTags.map(SyncDayTagsRow.init),
            profile: profile.map(SyncProfilePush.init)
        )
    }
}

/// One response, ready to be applied — the four ordered steps of SYNC.md §5.1 step 7, in one
/// transaction, as one value.
///
/// Bundled rather than passed as five arguments because the order is the contract and a caller
/// that could interleave the steps would be able to get it wrong: pulled rows before flags are
/// cleared, rejections last, cursor only if all of it committed.
struct SyncApplication: Sendable {
    /// The response's `user_id`. Written into `sync_state` when the row has none yet, and into
    /// `user_profile` alongside a pulled profile, which has no id of its own.
    var userId: String?
    var changes: SyncChangesPull?
    var rejected: [SyncRejection] = []
    /// `nil` on a pull-only run, and then step 7.2 does not run at all. Substituting zero would
    /// be harmless arithmetically and disastrous as a habit — the neighbouring mistake, "clear
    /// every flag", declares the whole backfilled database sent (§5.1).
    var sentMax: Int?
    var nextCursor: Int
    var importStatus: String?
}
