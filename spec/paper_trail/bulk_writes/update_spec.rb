# frozen_string_literal: true

RSpec.describe PaperTrail::BulkWrites::Update, :versioning do
  def versions_for(record)
    PaperTrail::Version.where(item_type: 'Widget', item_id: record.id)
  end

  def widget(**attributes)
    Widget.create!(name: 'w', status: :draft, quantity: 3, **attributes)
  end

  describe 'equivalence with a callback-written version' do
    it 'records the same object_changes as update! does' do
      via_callback = widget
      via_bulk = widget

      via_callback.update!(status: :filled, quantity: 0)
      described_class.call(scope: [via_bulk], attributes: { status: :filled, quantity: 0 })

      bulk_changes = versions_for(via_bulk).last.object_changes
      callback_changes = versions_for(via_callback).last.object_changes

      expect(bulk_changes.keys).to match_array(callback_changes.keys)
      expect(bulk_changes.except('updated_at')).to eq(callback_changes.except('updated_at'))
    end
  end

  describe 'the write itself' do
    it 'applies the attributes and bumps updated_at' do
      record = widget(updated_at: 1.day.ago)

      expect { described_class.call(scope: [record], attributes: { status: :filled }) }
        .to change { record.reload.status }.to('filled')
        .and(change { record.reload.updated_at })
    end

    it 'leaves updated_at alone when touch is false' do
      record = widget(updated_at: 1.day.ago)

      expect { described_class.call(scope: [record], attributes: { status: :filled }, touch: false) }
        .to change { record.reload.status }.to('filled')
        .and(not_change { record.reload.updated_at })
    end

    it 'records the concrete class as the item subtype for a single-table-inheritance scope' do
      gadget = Gadget.create!(name: 'g')

      Gadget.where(id: gadget.id).audited_update_all(attributes: { quantity: 10 })

      expect(gadget.versions.last.item_subtype).to eq('Gadget')
    end

    it 'returns the number of records written' do
      records = [widget, widget]

      expect(described_class.call(scope: records, attributes: { status: :filled })).to eq(2)
    end

    it 'does no work for an empty collection' do
      expect { described_class.call(scope: [], attributes: { status: :filled }) }
        .not_to(change(PaperTrail::Version, :count))
    end
  end

  describe 'version rows' do
    it 'writes one version per record' do
      records = [widget, widget]

      expect { described_class.call(scope: records, attributes: { status: :filled }) }
        .to change { PaperTrail::Version.where(item_type: 'Widget', event: 'update').count }.by(2)
    end

    it 'records whodunnit' do
      record = widget

      described_class.call(scope: [record], attributes: { status: :filled }, whodunnit: '42')

      expect(versions_for(record).last.whodunnit).to eq('42')
    end

    it 'records the touched updated_at, as update! does' do
      record = widget(updated_at: 1.day.ago)

      described_class.call(scope: [record], attributes: { status: :filled })

      expect(versions_for(record).last.object_changes.keys).to match_array(%w[status updated_at])
    end

    it 'omits updated_at when touch is false' do
      record = widget

      described_class.call(scope: [record], attributes: { status: :filled }, touch: false)

      expect(versions_for(record).last.object_changes.keys).to eq(['status'])
    end

    it 'omits updated_at when the model ignores it' do
      note = Note.create!(body: 'b')

      described_class.call(scope: [note], attributes: { body: 'c' })

      expect(PaperTrail::Version.where(item_type: 'Note').last.object_changes.keys).to eq(['body'])
    end

    it 'casts enum values so an unchanged attribute records no change' do
      record = widget

      expect { described_class.call(scope: [record], attributes: { status: :draft }, touch: false) }
        .not_to(change { PaperTrail::Version.where(item_type: 'Widget').count })
    end

    it 'records a touch-only version when nothing but updated_at changed, as touch does' do
      record = widget

      expect { described_class.call(scope: [record], attributes: { status: :draft }) }
        .to change { PaperTrail::Version.where(item_type: 'Widget').count }.by(1)

      expect(versions_for(record).last.object_changes.keys).to eq(['updated_at'])
    end

    it 'writes no version for a model without paper_trail' do
      plain = PlainRecord.create!(name: 'p')

      expect { described_class.call(scope: [plain], attributes: { name: 'q' }) }
        .not_to(change(PaperTrail::Version, :count))
    end
  end

  describe 'when given a relation rather than loaded records' do
    it 'records the same object_changes as the loaded-records path' do
      via_records = widget
      via_relation = widget

      described_class.call(scope: [via_records], attributes: { status: :filled, quantity: 0 })
      described_class.call(scope: Widget.where(id: via_relation.id), attributes: { status: :filled, quantity: 0 })

      expect(versions_for(via_relation).last.object_changes.except('updated_at'))
        .to eq(versions_for(via_records).last.object_changes.except('updated_at'))
    end

    it 'does not load the relation' do
      relation = Widget.where(id: widget.id)

      described_class.call(scope: relation, attributes: { status: :filled })

      expect(relation).not_to be_loaded
    end

    it 'writes in batches without missing records' do
      ids = [widget, widget, widget].map(&:id)

      result = described_class.call(scope: Widget.where(id: ids), attributes: { status: :filled }, batch_size: 2)

      expect(result).to eq(3)
      expect(Widget.where(id: ids).pluck(:status).uniq).to eq(['filled'])
    end

    it 'writes one version per record across batches' do
      ids = [widget, widget, widget].map(&:id)

      expect do
        described_class.call(scope: Widget.where(id: ids), attributes: { status: :filled }, batch_size: 2)
      end.to change { PaperTrail::Version.where(item_type: 'Widget', event: 'update').count }.by(3)
    end

    it 'terminates when the update invalidates the relation predicate' do
      ids = [widget, widget, widget].map(&:id)

      scope = Widget.where(id: ids, status: :draft)

      result = described_class.call(scope: scope, attributes: { status: :filled }, batch_size: 2)

      expect(result).to eq(3)
    end
  end

  describe '.audited_update_all' do
    it 'writes versions for a relation' do
      ids = [widget, widget].map(&:id)

      expect { Widget.where(id: ids).audited_update_all(attributes: { status: :filled }) }
        .to change { PaperTrail::Version.where(item_type: 'Widget', event: 'update').count }.by(2)
    end

    it 'leaves updated_at alone when touch is false' do
      record = widget(updated_at: 1.day.ago)

      expect { Widget.where(id: record.id).audited_update_all(attributes: { status: :filled }, touch: false) }
        .to change { record.reload.status }.to('filled')
        .and(not_change { record.reload.updated_at })
    end

    it 'defaults whodunnit to PaperTrail.request.whodunnit' do
      record = widget

      PaperTrail.request(whodunnit: 'request-user') do
        Widget.where(id: record.id).audited_update_all(attributes: { status: :filled })
      end

      expect(versions_for(record).last.whodunnit).to eq('request-user')
    end

    it 'uses the configured batch size' do
      PaperTrail::BulkWrites.configure { |c| c.batch_size = 1 }
      ids = [widget, widget].map(&:id)
      allow(Widget).to receive(:transaction).and_call_original

      Widget.where(id: ids).audited_update_all(attributes: { status: :filled })

      expect(Widget).to have_received(:transaction).twice
    end

    it 'writes only the rows in the relation it was called on' do
      target = widget
      bystander = widget

      Widget.where(id: target.id).audited_update_all(attributes: { quantity: 9 })

      expect(target.reload.quantity).to eq(9)
      expect(bystander.reload.quantity).to eq(3)
    end

    it 'narrows through a chain of scopes, not just an id list' do
      draft = widget
      active = widget(status: :active)

      Widget.where(id: [draft.id, active.id]).where(status: :draft).audited_update_all(attributes: { quantity: 9 })

      expect(draft.reload.quantity).to eq(9)
      expect(active.reload.quantity).to eq(3)
    end
  end

  describe 'a model that audits into its own version class' do
    let!(:contract) { Contract.create!(title: 'alpha', account_id: 7, state: 'open') }

    it 'writes to the model version class, not PaperTrail::Version' do
      expect { described_class.call(scope: [contract], attributes: { state: 'closed' }) }
        .to change { ContractVersion.where(item_type: 'Contract').count }.by(1)

      expect(PaperTrail::Version.where(item_type: 'Contract').count).to eq(0)
    end

    it 'populates the paper_trail meta columns from symbols and lambdas' do
      described_class.call(scope: [contract], attributes: { state: 'closed' })

      version = ContractVersion.where(item_type: 'Contract', item_id: contract.id).last

      expect(version.account_id).to eq(7)
      expect(version.label).to eq('contract-alpha')
    end

    it 'records the same object_changes and meta as update! does' do
      via_callback = Contract.create!(title: 'alpha', account_id: 7, state: 'open')

      via_callback.update!(state: 'closed')
      described_class.call(scope: [contract], attributes: { state: 'closed' })

      expected = ContractVersion.where(item_id: via_callback.id).last
      actual = ContractVersion.where(item_id: contract.id).last

      expect(actual.object_changes.except('updated_at')).to eq(expected.object_changes.except('updated_at'))
      expect(actual.attributes.slice('account_id', 'label')).to eq(expected.attributes.slice('account_id', 'label'))
    end

    it 'populates meta when given a relation, not only loaded records' do
      described_class.call(scope: Contract.where(id: contract.id), attributes: { state: 'closed' })

      version = ContractVersion.where(item_type: 'Contract', item_id: contract.id).last

      expect(version.account_id).to eq(7)
    end
  end

  describe 'staleness parity with paper_trail' do
    it 'records the same stale previous value that update! records' do
      via_callback = widget
      via_bulk = widget

      Widget.where(id: [via_callback.id, via_bulk.id]).update_all(status: 'active')

      via_callback.update!(status: :filled)
      described_class.call(scope: [via_bulk], attributes: { status: :filled })

      expect(versions_for(via_bulk).last.object_changes['status'])
        .to eq(versions_for(via_callback).last.object_changes['status'])
    end

    it 'reports the in-memory value as previous, as paper_trail does, not the committed one' do
      record = widget
      Widget.where(id: record.id).update_all(status: 'active')

      described_class.call(scope: [record], attributes: { status: :filled })

      expect(versions_for(record).last.object_changes['status']).to eq(%w[draft filled])
    end
  end

  describe "a model configured with paper_trail's only: option" do
    it 'audits only the configured fields, as update! does' do
      via_callback = Ticket.create!(title: 't', priority: 'low')
      via_bulk = Ticket.create!(title: 't', priority: 'low')

      via_callback.update!(title: 'u', priority: 'high')
      described_class.call(scope: [via_bulk], attributes: { title: 'u', priority: 'high' }, touch: false)

      expected = PaperTrail::Version.where(item_type: 'Ticket', item_id: via_callback.id).last
      actual = PaperTrail::Version.where(item_type: 'Ticket', item_id: via_bulk.id).last

      expect(actual.object_changes.keys).to eq(expected.object_changes.keys)
      expect(actual.object_changes.keys).to eq(['priority'])
    end

    it 'records no version when no configured field changed' do
      ticket = Ticket.create!(title: 't', priority: 'low')

      expect { described_class.call(scope: [ticket], attributes: { title: 'u' }) }
        .not_to(change { PaperTrail::Version.where(item_type: 'Ticket').count })
    end
  end

  describe "a model configured with paper_trail's ignore: and skip: options" do
    it 'leaves ignored and skipped columns out of object_changes' do
      note = Note.create!(body: 'b', views: 1, secret: 's')

      described_class.call(scope: [note], attributes: { body: 'c', views: 2, secret: 't' })

      expect(PaperTrail::Version.where(item_type: 'Note').last.object_changes.keys).to eq(['body'])
    end
  end

  describe 'scope-predicate handling' do
    def stale_widget
      record = widget(quantity: 1)
      records = Widget.where(id: record.id, status: :draft).to_a
      Widget.where(id: record.id).update_all(status: 'active')
      [record, records]
    end

    context 'when the caller has already loaded the records' do
      it 'writes them by id even once they no longer match, exactly as update! does' do
        callback_record, callback_records = stale_widget
        bulk_record, bulk_records = stale_widget

        callback_records.first.update!(quantity: 7)
        described_class.call(scope: bulk_records, attributes: { quantity: 7 })

        expect(bulk_record.reload.quantity).to eq(callback_record.reload.quantity)
      end

      it 'writes the row, where a bare update_all on the same scope would not' do
        audited_record, audited_records = stale_widget
        bulk_record, = stale_widget

        described_class.call(scope: audited_records, attributes: { quantity: 7 })
        Widget.where(id: bulk_record.id, status: :draft).update_all(quantity: 7)

        expect(audited_record.reload.quantity).to eq(7)
        expect(bulk_record.reload.quantity).to eq(1)
      end
    end

    context 'when given a relation it has not loaded' do
      it 'reapplies the predicate when reading the batch, so a row that stopped matching is skipped' do
        record = widget(quantity: 1)
        Widget.where(id: record.id).update_all(status: 'active')

        described_class.call(scope: Widget.where(id: record.id, status: :draft), attributes: { quantity: 7 })

        expect(record.reload.quantity).to eq(1)
      end

      it 'writes rows that still match' do
        record = widget(quantity: 1)

        described_class.call(scope: Widget.where(id: record.id, status: :draft), attributes: { quantity: 7 })

        expect(record.reload.quantity).to eq(7)
      end
    end
  end

  describe 'atomicity of the data write and the version write' do
    it 'rolls the data write back when the version insert fails' do
      record = widget
      allow(PaperTrail::Version).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect { described_class.call(scope: [record], attributes: { status: :filled }) }
        .to raise_error(ActiveRecord::StatementInvalid)

      expect(record.reload.status).to eq('draft')
    end

    it 'leaves no version behind when the data write fails' do
      record = widget
      versions_before = versions_for(record).count
      allow(Widget).to receive(:where).and_wrap_original do |original, *args|
        relation = original.call(*args)
        allow(relation).to receive(:update_all).and_raise(ActiveRecord::StatementInvalid, 'boom')
        relation
      end

      expect { described_class.call(scope: [record], attributes: { status: :filled }) }
        .to raise_error(ActiveRecord::StatementInvalid)

      expect(versions_for(record).count).to eq(versions_before)
    end
  end
end
