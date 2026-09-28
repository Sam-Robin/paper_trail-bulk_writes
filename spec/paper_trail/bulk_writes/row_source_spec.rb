# frozen_string_literal: true

RSpec.describe PaperTrail::BulkWrites::RowSource do
  def rows_from(source, batch_size: 1_000)
    [].tap { |batches| source.each_batch(batch_size) { |rows| batches << rows } }
  end

  def source_for(scope, model, tracked)
    described_class.new(scope, tracked: tracked, adapter: PaperTrail::BulkWrites::Adapter.new(model, whodunnit: nil))
  end

  def widget
    Widget.create!(name: 'w', status: :draft, quantity: 3)
  end

  describe 'an unloaded relation on a model without meta' do
    it 'yields id, previous values and empty extra per record' do
      record = widget

      rows = rows_from(source_for(Widget.where(id: record.id), Widget, %w[status])).flatten(1)

      expect(rows).to eq([[record.id, { 'status' => 'draft' }, {}]])
    end

    it 'does not load the relation' do
      relation = Widget.where(id: widget.id)

      rows_from(source_for(relation, Widget, %w[status]))

      expect(relation).not_to be_loaded
    end
  end

  describe 'loaded records' do
    it 'reads previous values off the instances' do
      record = widget

      rows = rows_from(source_for([record], Widget, %w[status quantity])).flatten(1)

      expect(rows).to eq([[record.id, { 'status' => 'draft', 'quantity' => 3 }, {}]])
    end

    it 'resolves meta into the extra slot' do
      contract = Contract.create!(title: 'alpha', account_id: 7)

      rows = rows_from(source_for([contract], Contract, %w[state])).flatten(1)

      expect(rows.first.last).to eq(account_id: 7, label: 'contract-alpha')
    end
  end

  describe 'a relation on a model with meta' do
    it 'falls back to loading records so meta can be resolved' do
      contract = Contract.create!(title: 'alpha', account_id: 7)

      rows = rows_from(source_for(Contract.where(id: contract.id), Contract, %w[state])).flatten(1)

      expect(rows.first.last).to include(account_id: 7)
    end
  end

  describe 'batching' do
    it 'slices loaded records into batches of the requested size' do
      batches = rows_from(source_for([widget, widget, widget], Widget, %w[status]), batch_size: 2)

      expect(batches.map(&:size)).to eq([2, 1])
    end

    it 'walks a relation in batches of the requested size' do
      ids = [widget, widget, widget].map(&:id)

      batches = rows_from(source_for(Widget.where(id: ids), Widget, %w[status]), batch_size: 2)

      expect(batches.map(&:size)).to eq([2, 1])
    end
  end
end
