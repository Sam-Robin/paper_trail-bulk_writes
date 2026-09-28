# Changelog

## Unreleased

## 0.1.0

- `PaperTrail::BulkWrites::Model` with `audited_update_all`, `audited_delete_all` and `audited_insert_all`.
- Honours `only:`, `ignore:`, `skip:`, `meta:` and `versions:` from `has_paper_trail`; sets `item_subtype` for STI.
- `PaperTrail::BulkWrites.configure { |c| c.batch_size = ... }`.
- `PaperTrail/BulkWrites/NoBulkWriteOnAuditedModel` RuboCop cop, configured with a `Models:` list; flags `update_all`, `delete_all`, `insert_all`, `insert_all!` and `upsert_all`.
