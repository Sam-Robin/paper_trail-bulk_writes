# frozen_string_literal: true

RSpec.describe PaperTrail::BulkWrites::Adapter, :versioning do
  describe '#tracked' do
    it 'keeps every candidate for a model with no ignore, skip or only configuration' do
      adapter = described_class.new(Widget, whodunnit: nil)

      expect(adapter.tracked(%w[status updated_at])).to eq(%w[status updated_at])
    end

    it 'stringifies symbol candidates' do
      expect(described_class.new(Widget, whodunnit: nil).tracked([:status])).to eq(%w[status])
    end

    it "applies the model's only: configuration" do
      adapter = described_class.new(Ticket, whodunnit: nil)

      expect(adapter.tracked(%w[priority title])).to eq(%w[priority])
    end

    it "applies the model's ignore: and skip: configuration" do
      adapter = described_class.new(Note, whodunnit: nil)

      expect(adapter.tracked(%w[body views secret])).to eq(%w[body])
    end

    it 'keeps every candidate for a model without paper_trail' do
      adapter = described_class.new(PlainRecord, whodunnit: nil)

      expect(adapter.tracked(%w[name updated_at])).to eq(%w[name updated_at])
    end
  end

  describe '#meta' do
    it 'is empty for a model without meta configuration' do
      expect(described_class.new(Widget, whodunnit: nil).meta).to eq({})
    end

    it 'is empty for a model without paper_trail' do
      expect(described_class.new(PlainRecord, whodunnit: nil).meta).to eq({})
    end
  end

  describe '#meta_for' do
    it "resolves the model's meta symbols and lambdas against the record" do
      contract = Contract.new(title: 'alpha', account_id: 7)

      expect(described_class.new(Contract, whodunnit: nil).meta_for(contract))
        .to eq(account_id: 7, label: 'contract-alpha')
    end
  end

  describe '#build_row' do
    it 'shapes a version row with the whodunnit and merged extra' do
      adapter = described_class.new(Widget, whodunnit: '42')

      row = adapter.build_row(id: 7, event: 'update', object_changes: { 'status' => %w[draft filled] },
                              extra: { label: 'x' })

      expect(row).to include(item_type: 'Widget', item_id: 7, event: 'update', whodunnit: '42', label: 'x')
      expect(row[:object_changes]).to eq('status' => %w[draft filled])
      expect(row[:created_at]).to be_present
    end

    it 'records the subtype for a single-table-inheritance subclass' do
      row = described_class.new(Gadget, whodunnit: nil).build_row(id: 1, event: 'update', object_changes: {}, extra: {})

      expect(row).to include(item_type: 'Widget', item_subtype: 'Gadget')
    end
  end

  describe '#insert' do
    it "writes rows into the model's version class" do
      widget = Widget.create!(name: 'w')
      adapter = described_class.new(Widget, whodunnit: nil)
      row = adapter.build_row(id: widget.id, event: 'update', object_changes: { 'status' => %w[draft filled] },
                              extra: {})

      expect { adapter.insert([row]) }
        .to change { PaperTrail::Version.where(item_type: 'Widget', item_id: widget.id).count }.by(1)
    end

    it "writes into the model's own version class when one is configured" do
      contract = Contract.create!(title: 'alpha')
      adapter = described_class.new(Contract, whodunnit: nil)
      row = adapter.build_row(id: contract.id, event: 'update', object_changes: {}, extra: adapter.meta_for(contract))

      expect { adapter.insert([row]) }.to change { ContractVersion.where(item_id: contract.id).count }.by(1)
    end

    it 'is a no-op for a model without paper_trail' do
      adapter = described_class.new(PlainRecord, whodunnit: nil)

      expect { adapter.insert([{ item_type: 'PlainRecord', item_id: 1 }]) }.not_to change(PaperTrail::Version, :count)
    end

    it 'is a no-op for an empty batch' do
      expect { described_class.new(Widget, whodunnit: nil).insert([]) }.not_to change(PaperTrail::Version, :count)
    end
  end
end
