# frozen_string_literal: true

RSpec.describe PaperTrail::BulkWrites::Insert, :versioning do
  def versions_for(id)
    PaperTrail::Version.where(item_type: 'Widget', item_id: id)
  end

  def row(name)
    { name: name, status: 'active', quantity: 1 }
  end

  describe 'equivalence with a callback-written version' do
    it 'records the same object_changes keys as create! does' do
      via_callback = Widget.create!(row('one'))
      via_bulk_id = described_class.call(model: Widget, rows: [row('two')]).sole

      expect(versions_for(via_bulk_id).sole.object_changes.keys)
        .to match_array(versions_for(via_callback.id).sole.object_changes.keys)
    end

    it 'leaves defaulted columns the caller did not supply out of object_changes, as create! does' do
      via_callback = Widget.create!(name: 'one')
      via_bulk_id = described_class.call(model: Widget, rows: [{ name: 'two' }]).sole

      expect(versions_for(via_bulk_id).sole.object_changes.keys)
        .to match_array(versions_for(via_callback.id).sole.object_changes.keys)
    end

    it 'records a create event with the new values and the whodunnit' do
      id = described_class.call(model: Widget, rows: [row('two')], whodunnit: '42').sole

      version = versions_for(id).sole
      expect(version).to have_attributes(event: 'create', whodunnit: '42')
      expect(version.object_changes['name']).to eq([nil, 'two'])
      expect(version.object_changes['id']).to eq([nil, id])
    end
  end

  describe 'a single-table-inheritance model' do
    it 'records the concrete class as the item subtype, like create! does' do
      via_callback = Gadget.create!(name: 'g')
      attributes = via_callback.attributes.except('id', 'created_at', 'updated_at')

      id = Gadget.audited_insert_all([attributes]).sole

      version = PaperTrail::Version.find_by(item_type: 'Widget', item_id: id, event: 'create')
      expect(version.item_subtype).to eq('Gadget')
      expect(via_callback.versions.sole.item_subtype).to eq('Gadget')
    end
  end

  describe 'a model with meta' do
    it 'resolves meta from the inserted attributes' do
      id = Contract.audited_insert_all([{ title: 'alpha', account_id: 7 }]).sole

      version = ContractVersion.find_by(item_id: id, event: 'create')

      expect(version).to have_attributes(account_id: 7, label: 'contract-alpha')
    end
  end

  describe 'the write itself' do
    it 'inserts every row with timestamps and returns the ids in input order' do
      ids = described_class.call(model: Widget, rows: [row('a'), row('b')])

      expect(ids.map { |id| Widget.find(id).name }).to eq(%w[a b])
      expect(Widget.find(ids.first).created_at).to be_present
    end

    it 'casts the returned values like a callback-written version does' do
      id = described_class.call(model: Widget, rows: [row('cast')]).sole

      changes = versions_for(id).sole.object_changes
      expect(changes['quantity'].last).to eq(1)
      expect(changes['name'].last).to eq('cast')
    end

    it 'is reachable through audited_insert_all on the model' do
      id = Widget.audited_insert_all([row('wired')], whodunnit: '7').sole

      expect(Widget.find(id).name).to eq('wired')
      expect(versions_for(id).sole).to have_attributes(event: 'create', whodunnit: '7')
    end

    it 'writes one version per row across batches' do
      ids = described_class.call(model: Widget, rows: [row('a'), row('b'), row('c')], batch_size: 2)

      expect(PaperTrail::Version.where(item_type: 'Widget', item_id: ids, event: 'create').count).to eq(3)
    end

    it 'returns an empty array and writes nothing for no rows' do
      expect(described_class.call(model: Widget, rows: [])).to eq([])
      expect(PaperTrail::Version.where(item_type: 'Widget').count).to eq(0)
    end

    it 'writes no version for a model without paper_trail' do
      expect { PlainRecord.audited_insert_all([{ name: 'p' }]) }
        .to change(PlainRecord, :count).by(1)
        .and(not_change(PaperTrail::Version, :count))
    end

    it 'rolls every batch back, rows and versions, when a later batch fails' do
      expect { described_class.call(model: Widget, rows: [row('a'), { name: 'b', status: nil }], batch_size: 1) }
        .to raise_error(ActiveRecord::NotNullViolation)

      expect(Widget.exists?(name: 'a')).to be(false)
      expect(PaperTrail::Version.where(item_type: 'Widget').count).to eq(0)
    end

    it 'rolls the rows back when their versions cannot be written' do
      allow(PaperTrail::Version).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'versions down')

      expect { described_class.call(model: Widget, rows: [row('a')]) }
        .to raise_error(ActiveRecord::StatementInvalid, 'versions down')

      expect(Widget.exists?(name: 'a')).to be(false)
      expect(PaperTrail::Version.where(item_type: 'Widget').count).to eq(0)
    end
  end
end
