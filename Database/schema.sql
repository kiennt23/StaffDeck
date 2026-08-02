CREATE TABLE IF NOT EXISTS synced_records (
    collection TEXT NOT NULL,
    record_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (collection, record_id)
);

CREATE INDEX IF NOT EXISTS synced_records_updated
ON synced_records(collection, updated_at);

