# Paper Trail Bulk Writes

PaperTrail versions for `update_all`, `delete_all` and `insert_all`.

Working on PostgreSQL (full support), SQLite 3.35+ and MySQL 5-7+, MariaDB 10.5+.

## The problem

[PaperTrail](https://github.com/paper-trail-gem/paper_trail) records versions from ActiveRecord callbacks. Bulk writes skip callbacks, so they leave no audit trail:

```ruby
Shift.where(id: ids).update_all(status: :filled)   # no version row
Shift.where(id: ids).delete_all                    # no version row
Shift.insert_all(rows)                             # no version row
```

The usual workaround is `find_each(&:update!)`, which is N queries and N version inserts. PaperTrail's maintainers have [declined to add bulk support](https://github.com/paper-trail-gem/paper_trail/issues/1533).

## What this gem does

```ruby
Shift.where(id: ids).audited_update_all(attributes: { status: :filled })
Shift.where(id: ids).audited_delete_all
Shift.audited_insert_all(rows)
```

Each call runs the bulk write and inserts one version row per record, in the same transaction, using two statements per batch instead of 2N. The version rows match what the callback path would have written:

- `object_changes` holds `[before, after]` per column, read from the database before the write (or from the loaded records, if you pass an array).
- `only:`, `ignore:` and `skip:` from `has_paper_trail` are honoured.
- `meta:` symbols and lambdas are resolved per record.
- A custom `versions: { class_name: }` is written to instead of `PaperTrail::Version`.
- `item_subtype` is set for single-table-inheritance models.
- `whodunnit` defaults to `PaperTrail.request.whodunnit`.
- `audited_update_all` touches `updated_at` like `update!` does (pass `touch: false` to skip).

## Install

```ruby
gem 'paper_trail-bulk_writes'
```

```ruby
class Shift < ApplicationRecord
  include PaperTrail::BulkWrites::Model

  has_paper_trail
end
```

## Usage

```ruby
# Relation or array of loaded records; returns the number of rows written.
Shift.where(company_id: company.id).audited_update_all(attributes: { archived: true })
Shift.where(id: ids).audited_update_all(attributes: { status: :filled }, touch: false, whodunnit: admin.id)

# Returns the number of rows deleted.
Shift.where(id: ids).audited_delete_all

# Returns the new ids, in input order. Rows are inserted with insert_all!.
Shift.audited_insert_all([{ name: 'a', status: 'draft' }, { name: 'b', status: 'draft' }])
```

Batches default to 1,000 rows:

```ruby
# config/initializers/paper_trail_bulk_writes.rb
PaperTrail::BulkWrites.configure do |config|
  config.batch_size = 500
end
```

### Semantics worth knowing

- **Loaded records are written by id**, exactly as `update!` would be, even if they no longer match the scope they were loaded from. An unloaded relation re-applies its predicate per batch, so a row that stopped matching is skipped.
- **Previous values come from the loaded record** when you pass an array, so if the row changed underneath you the version reports the stale value — the same thing PaperTrail's dirty tracking does.
- **A touch-only update writes a version** whose `object_changes` is just `updated_at`, like `touch` does. Ignore `updated_at` in `has_paper_trail` (or `PaperTrail.config.has_paper_trail_defaults`) if you don't want that.
- **Data and versions are one transaction.** If the version insert fails, the data write rolls back, and vice versa.

## RuboCop cop

The gem ships a cop that flags bare bulk writes on models you list as audited:

```yaml
# .rubocop.yml
require:
  - paper_trail/bulk_writes/rubocop

PaperTrail/BulkWrites/NoBulkWriteOnAuditedModel:
  Models:
    - Shift
    - Timesheet
    - Tasks::Task
```

```
Shift.where(id: ids).update_all(status: :filled)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `update_all` on Shift skips callbacks, so PaperTrail records no version. ...
```

It catches `update_all`, `delete_all`, `insert_all`, `insert_all!` and `upsert_all` when the call chain starts from a listed constant. It does not see relations held in locals or reached through associations (`scope.update_all`, `company.shifts.delete_all`) — the receiver has to be the model.

To keep `Models:` honest, add a spec that fails when a model gains `has_paper_trail` without being listed:

```ruby
RSpec.describe 'audited models are listed for the bulk-write cop' do
  it 'lists every model in app/models with has_paper_trail' do
    config = RuboCop::ConfigLoader.load_file('.rubocop.yml')
    listed = config['PaperTrail/BulkWrites/NoBulkWriteOnAuditedModel']['Models'].sort

    on_disk = Dir[Rails.root.join('app/models/**/*.rb')].filter_map do |path|
      next unless File.foreach(path).any? { |line| line.match?(/^\s*has_paper_trail\b/) }

      path.delete_prefix(Rails.root.join('app/models/').to_s).delete_suffix('.rb').camelize
    end.sort

    expect(listed).to eq(on_disk)
  end
end
```

## Limitations

- **`object` is not written**, only `object_changes`. `version.reify` won't work on bulk-written versions; use `where_object_changes` and friends.
- **`has_paper_trail on:`** is not consulted — every bulk write is versioned.
- Requires Ruby 3.2+, ActiveRecord 7.1+, PaperTrail 15+.

## Development

```sh
bundle install
bundle exec rspec                                   # SQLite in memory
DB=postgres DATABASE_URL=postgres://localhost/paper_trail_bulk_writes_test bundle exec rspec
bundle exec appraisal install && bundle exec appraisal rspec   # every Rails × PaperTrail combination
bundle exec rubocop
```

## License

MIT. Extracted from production code at [Florence](https://www.florence.co.uk).
