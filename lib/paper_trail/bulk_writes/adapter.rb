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
        inserted = insert_and_fetch(batch)
        changed = changed_columns(batch)
        adapter.insert(inserted.map { |attributes| version_row(attributes, changed) })
        inserted.pluck('id')
      end

      # Databases with RETURNING (Postgres, SQLite 3.35+, MariaDB 10.5+) hand the
      # inserted rows back directly.
      def insert_and_fetch(batch)
        if model.connection.supports_insert_returning?
          model.insert_all!(batch, returning: ['id', *tracked]).to_a
        else
          model.insert_all!(batch)
          fetch_rows(generated_ids(batch))
        end
      end

      # MySQL only does not give us inserted rows, so we need to get the ids back.
      def generated_ids(batch)
        supplied = batch.map { |row| row[:id] || row['id'] }
        return supplied if supplied.none?(&:nil?)
        raise ArgumentError, 'rows must all supply an id or none of them' unless supplied.all?(&:nil?)

        conn = model.connection
        first = conn.select_value('SELECT LAST_INSERT_ID()').to_i
        step = conn.select_value('SELECT @@auto_increment_increment').to_i
        Array.new(batch.size) { |i| first + (i * step) }
      end

      def fetch_rows(ids)
        relation = model.unscoped.where(id: ids).select('id', *tracked)
        by_id = model.connection.select_all(relation).to_a.index_by { |row| row['id'] }
        ids.map { |id| by_id.fetch(id) }
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
