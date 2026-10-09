# Changelog

## Unreleased

- Added: `audited_insert_all` takes `returning:`, a list of column names, and returns an `ActiveRecord::Result` of those columns in input order, like `insert_all`. Without it, it still returns the ids. Works on MySQL too, by reading the rows back.

## 0.2.0

- Fixed: on databases without `INSERT ... RETURNING`, `audited_insert_all` raised `KeyError` when the caller supplied ids typed differently to the column, such as strings out of a CSV or a JSON payload.

## 0.1.0

- `PaperTrail::BulkWrites::Model` with `audited_update_all`, `audited_delete_all` and `audited_insert_all`.
- Honours `only:`, `ignore:`, `skip:`, `meta:` and `versions:` from `has_paper_trail`; sets `item_subtype` for STI.
- `PaperTrail::BulkWrites.configure { |c| c.batch_size = ... }`.
- `PaperTrail/BulkWrites/NoBulkWriteOnAuditedModel` RuboCop cop, configured with a `Models:` list; flags `update_all`, `delete_all`, `insert_all`, `insert_all!` and `upsert_all`.
