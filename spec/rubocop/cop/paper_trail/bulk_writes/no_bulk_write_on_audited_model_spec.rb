# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require 'paper_trail/bulk_writes/rubocop'

RSpec.describe RuboCop::Cop::PaperTrail::BulkWrites::NoBulkWriteOnAuditedModel, :config do
  include RuboCop::RSpec::ExpectOffense

  let(:cop_config) { { 'Models' => ['Shift', 'Tasks::Task'] } }

  it 'registers an offense for update_all on an audited model' do
    expect_offense(<<~RUBY)
      Shift.where(id: ids).update_all(status: :approved)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `update_all` on Shift skips callbacks, so PaperTrail records no version. Use `audited_update_all` (include `PaperTrail::BulkWrites::Model` on the model), or `each(&:update!)` when you want the record callbacks to run too.
    RUBY
  end

  it 'registers an offense for delete_all on an audited model' do
    expect_offense(<<~RUBY)
      Shift.where(id: ids).delete_all
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `delete_all` on Shift skips callbacks, so PaperTrail records no version. Use `audited_delete_all` (include `PaperTrail::BulkWrites::Model` on the model), or `destroy_all` when you want the record callbacks to run too.
    RUBY
  end

  it 'registers an offense for insert_all, insert_all! and upsert_all on an audited model' do
    expect_offense(<<~RUBY)
      Shift.insert_all(rows)
      ^^^^^^^^^^^^^^^^^^^^^^ `insert_all` on Shift skips callbacks, so PaperTrail records no version. Use `audited_insert_all` (include `PaperTrail::BulkWrites::Model` on the model), or `create!` when you want the record callbacks to run too.
      Shift.insert_all!(rows)
      ^^^^^^^^^^^^^^^^^^^^^^^ `insert_all!` on Shift skips callbacks, so PaperTrail records no version. Use `audited_insert_all` (include `PaperTrail::BulkWrites::Model` on the model), or `create!` when you want the record callbacks to run too.
      Shift.upsert_all(rows)
      ^^^^^^^^^^^^^^^^^^^^^^ `upsert_all` on Shift skips callbacks, so PaperTrail records no version. Use `audited_insert_all` (include `PaperTrail::BulkWrites::Model` on the model), or `create!` when you want the record callbacks to run too.
    RUBY
  end

  it 'registers an offense through a long relation chain' do
    expect_offense(<<~RUBY)
      Shift.where(company_id: company.id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `update_all` on Shift skips callbacks, [...]
          .where.not(id: excluded_ids)
          .in_batches
          .update_all(region_id: region.id)
    RUBY
  end

  it 'registers an offense for a namespaced audited model' do
    expect_offense(<<~RUBY)
      Tasks::Task.where(id: ids).update_all(priority: 1)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `update_all` on Tasks::Task skips callbacks, [...]
    RUBY
  end

  it 'registers an offense for a top-level qualified constant' do
    expect_offense(<<~RUBY)
      ::Shift.where(id: ids).delete_all
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `delete_all` on Shift skips callbacks, [...]
    RUBY
  end

  it 'does not register an offense for destroy_all, which versions each record' do
    expect_no_offenses('Shift.where(id: ids).destroy_all')
  end

  it 'does not register an offense for the audited bulk-write helpers' do
    expect_no_offenses(<<~RUBY)
      Shift.where(id: ids).audited_update_all(attributes: { archived: true })
      Shift.where(id: ids).audited_delete_all
      Shift.audited_insert_all(rows)
    RUBY
  end

  it 'does not register an offense for a model that is not listed' do
    expect_no_offenses('Distance.where(user: user).delete_all')
  end

  it 'does not register an offense when the relation is held in a local' do
    expect_no_offenses('scope.update_all(payroll_group_id: nil)')
  end

  it 'does not register an offense when the relation comes from an association' do
    expect_no_offenses('company.shifts.update_all(archived: true)')
  end

  context 'when no models are configured' do
    let(:cop_config) { { 'Models' => [] } }

    it 'registers nothing' do
      expect_no_offenses('Shift.where(id: ids).update_all(status: :approved)')
    end
  end
end
