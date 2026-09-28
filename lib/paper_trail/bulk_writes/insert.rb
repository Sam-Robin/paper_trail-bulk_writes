# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Insert
      include Versioned

      def initialize(model:, rows:, whodunnit: nil, batch_size: nil)
        @model = model
        @rows = rows
        @whodunnit = whodunnit
        @batch_size = batch_size || default_batch_size
      end

      def call
        return [] if rows.empty?

        model.transaction { rows.each_slice(batch_size).flat_map { |batch| write(batch) } }
      end

      private

      attr_reader :model, :rows, :whodunnit, :batch_size

      def tracked
        @tracked ||= adapter.tracked(model.column_names) - ['id']
      end

      def write(batch)
        inserted = model.insert_all!(batch, returning: ['id', *tracked]).to_a
        changed = changed_columns(batch)
        adapter.insert(inserted.map { |attributes| version_row(attributes, changed) })
        inserted.pluck('id')
      end

      def changed_columns(batch)
        supplied = batch.flat_map { |row| row.keys.map(&:to_s) }.uniq
        (supplied + %w[id created_at updated_at]) & ['id', *tracked]
      end

      def version_row(attributes, changed)
        adapter.build_row(
          id: attributes['id'],
          event: 'create',
          object_changes: object_changes_for(attributes.slice(*changed)),
          extra: adapter.meta.any? ? adapter.meta_for(model.new(attributes)) : {},
          subtype: attributes[model.inheritance_column]
        )
      end

      def object_changes_for(attributes)
        attributes.compact.to_h { |name, value| [name, [nil, model.type_for_attribute(name).cast(value)]] }
      end
    end
  end
end
