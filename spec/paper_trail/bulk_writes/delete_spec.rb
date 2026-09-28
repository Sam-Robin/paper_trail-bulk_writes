# frozen_string_literal: true

RSpec.describe PaperTrail::BulkWrites::Delete, :versioning do
  def versions_for(record)
    PaperTrail::Version.where(item_type: 'Widget', item_id: record.id)
  end

  def widget(**attributes)
    Widget.create!(name: 'w', status: :draft, quantity: 3, **attributes)
  end

  describe 'equivalence with a callback-written version' do
    it 'records the same attributes as destroy! does' do
      via_callback = widget
      via_bulk = widget

      via_callback.destroy!
      described_class.call(scope: [via_bulk])

      expect(versions_for(via_bulk).last.object_changes.keys)
        .to match_array(versions_for(via_callback).last.object_changes.keys)
    end

    it 'records a destroy event' do
      record = widget

      described_class.call(scope: [record])

      expect(versions_for(record).last.event).to eq('destroy')
    end
  end

  describe 'the delete itself' do
    it 'removes the rows' do
      record = widget

      expect { described_class.call(scope: [record]) }
        .to change { Widget.exists?(record.id) }.from(true).to(false)
    end

    it 'returns the number of records deleted' do
      expect(described_class.call(scope: [widget, widget])).to eq(2)
    end

    it 'does no work for an empty collection' do
      expect { described_class.call(scope: []) }.not_to(change(PaperTrail::Version, :count))
    end

    it 'deletes only the rows in the scope it was given' do
      target = widget
      bystander = widget

      described_class.call(scope: Widget.where(id: target.id))

      expect(Widget.exists?(target.id)).to be false
      expect(Widget.exists?(bystander.id)).to be true
    end
  end

  describe 'version rows' do
    it 'writes one version per record' do
      records = [widget, widget]

      expect { described_class.call(scope: records) }
        .to change { PaperTrail::Version.where(item_type: 'Widget', event: 'destroy').count }.by(2)
    end

    it 'records whodunnit' do
      record = widget

      described_class.call(scope: [record], whodunnit: '42')

      expect(versions_for(record).last.whodunnit).to eq('42')
    end

    it 'records every tracked attribute as having gone to nil' do
      record = widget

      described_class.call(scope: [record])

      changes = versions_for(record).last.object_changes

      expect(changes['status']).to eq(['draft', nil])
      expect(changes['quantity']).to eq([3, nil])
      expect(changes['id']).to eq([record.id, nil])
    end

    it 'omits columns the model ignores' do
      note = Note.create!(body: 'b')

      described_class.call(scope: [note])

      expect(PaperTrail::Version.where(item_type: 'Note').last.object_changes.keys)
        .to match_array(%w[id body created_at])
    end

    it 'records the concrete class as the item subtype for a single-table-inheritance model' do
      gadget = Gadget.create!(name: 'g')

      described_class.call(scope: [gadget])

      expect(PaperTrail::Version.where(item_type: 'Widget', item_id: gadget.id).last.item_subtype).to eq('Gadget')
    end

    it 'writes no version for a model without paper_trail' do
      plain = PlainRecord.create!(name: 'p')

      expect { described_class.call(scope: [plain]) }.not_to(change(PaperTrail::Version, :count))
    end
  end

  describe 'when given a relation rather than loaded records' do
    it 'reads the attributes before the row is deleted' do
      record = widget

      described_class.call(scope: Widget.where(id: record.id))

      expect(versions_for(record).last.object_changes['quantity']).to eq([3, nil])
    end

    it 'does not load the relation' do
      relation = Widget.where(id: widget.id)

      described_class.call(scope: relation)

      expect(relation).not_to be_loaded
    end

    it 'deletes in batches without missing records' do
      ids = [widget, widget, widget].map(&:id)

      result = described_class.call(scope: Widget.where(id: ids), batch_size: 2)

      expect(result).to eq(3)
      expect(Widget.where(id: ids)).to be_empty
    end

    it 'writes one version per record across batches' do
      ids = [widget, widget, widget].map(&:id)

      expect { described_class.call(scope: Widget.where(id: ids), batch_size: 2) }
        .to change { PaperTrail::Version.where(item_type: 'Widget', event: 'destroy').count }.by(3)
    end

    it 'narrows through a chain of scopes, not just an id list' do
      draft = widget
      active = widget(status: :active)

      described_class.call(scope: Widget.where(id: [draft.id, active.id]).where(status: :draft))

      expect(Widget.exists?(draft.id)).to be false
      expect(Widget.exists?(active.id)).to be true
    end
  end

  describe '.audited_delete_all' do
    it 'writes versions and deletes the rows for a relation' do
      ids = [widget, widget].map(&:id)

      expect { Widget.where(id: ids).audited_delete_all }
        .to change { PaperTrail::Version.where(item_type: 'Widget', event: 'destroy').count }.by(2)
        .and(change { Widget.where(id: ids).count }.from(2).to(0))
    end

    it 'defaults whodunnit to PaperTrail.request.whodunnit' do
      record = widget

      PaperTrail.request(whodunnit: 'request-user') { Widget.where(id: record.id).audited_delete_all }

      expect(versions_for(record).last.whodunnit).to eq('request-user')
    end
  end

  describe "a model configured with paper_trail's only: option" do
    it 'audits only the configured fields' do
      ticket = Ticket.create!(title: 't', priority: 'low')

      described_class.call(scope: [ticket])

      expect(PaperTrail::Version.where(item_type: 'Ticket', item_id: ticket.id).last.object_changes.keys)
        .to eq(['priority'])
    end

    it 'writes a version even when no configured field was set' do
      ticket = Ticket.create!(title: 't')

      expect { described_class.call(scope: [ticket]) }
        .to change { PaperTrail::Version.where(item_type: 'Ticket', event: 'destroy').count }.by(1)
    end
  end

  describe 'a model that audits into its own version class' do
    let!(:contract) { Contract.create!(title: 'alpha', account_id: 7) }

    def destroy_versions_for(record)
      ContractVersion.where(item_type: 'Contract', item_id: record.id, event: 'destroy')
    end

    it 'writes the destroy version to the model version class, not PaperTrail::Version' do
      expect { described_class.call(scope: [contract]) }
        .to change { destroy_versions_for(contract).count }.by(1)

      expect(PaperTrail::Version.where(item_type: 'Contract').count).to eq(0)
    end

    it 'populates the paper_trail meta columns' do
      described_class.call(scope: [contract])

      expect(destroy_versions_for(contract).last).to have_attributes(account_id: 7, label: 'contract-alpha')
    end

    it 'populates meta when given a relation, not only loaded records' do
      described_class.call(scope: Contract.where(id: contract.id))

      expect(destroy_versions_for(contract).last.account_id).to eq(7)
    end
  end

  describe 'atomicity of the data write and the version write' do
    it 'rolls the delete back when the version insert fails' do
      record = widget
      allow(PaperTrail::Version).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect { described_class.call(scope: [record]) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(Widget.exists?(record.id)).to be true
    end

    it 'leaves no version behind when the delete fails' do
      record = widget
      versions_before = versions_for(record).count
      allow(Widget).to receive(:where).and_wrap_original do |original, *args|
        relation = original.call(*args)
        allow(relation).to receive(:delete_all).and_raise(ActiveRecord::StatementInvalid, 'boom')
        relation
      end

      expect { described_class.call(scope: [record]) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(versions_for(record).count).to eq(versions_before)
    end
  end
end
