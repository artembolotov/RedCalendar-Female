import GRDB

/// A row that carries the "edited here, not yet pushed" generation of SYNC.md §5.4.
///
/// Nobody who builds a record fills this in. The value is `sync_state.local_seq`, and it is only
/// right if it is bumped and read inside the very transaction the row is written in — an edit
/// that happened while a sync run was in flight has to come out with a *higher* generation than
/// the run reported sending, or the run clears its flag and the edit is lost. `DatabaseService`
/// is the one place that does the stamping, for every table.
protocol DirtyStamped: PersistableRecord, Sendable {
    var dirtySeq: Int? { get set }
}
