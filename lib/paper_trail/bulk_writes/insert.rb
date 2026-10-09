# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Insert
      include Versioned

      def initialize(model:, rows:, whodunnit: nil, batch_size: nil, returning: nil)
        @model = model
        @rows = rows
        @whodunnit = whodunnit
        @batch_size = batch_size || default_batch_size
        @returning = returning && Array(returning).map(&:to_s)
      end

      def call
        inserted = insert_all
        return inserted.pluck('id') unless returning

        ActiveRecord::Result.new(returning, inserted.map { |attributes| attributes.values_at(*returning) })
      end

      private

      attr_reader :model, :rows, :whodunnit, :batch_size, :returning

      def tracked
        @tracked ||= adapter.tracked(model.column_names) - ['id']
      end

      def fetched
        @fetched ||= ['id', *tracked] | returning.to_a
      end

      def insert_all
        return [] if rows.empty?

        model.transaction { rows.each_slice(batch_size).flat_map { |batch| write(batch) } }
      end

      def write(batch)
        inserted = insert_and_fetch(batch)
        changed = changed_columns(batch)
        adapter.insert(inserted.map { |attributes| version_row(attributes, changed) })
        inserted
      end

      # Databases with RETURNING (Postgres, SQLite 3.35+, MariaDB 10.5+) hand the
      # inserted rows back.
      def insert_and_fetch(batch)
        if model.connection.supports_insert_returning?
          model.insert_all!(batch, returning: fetched).to_a
        else
          supplied = supplied_ids(batch)
          model.insert_all!(batch)
          fetch_rows(supplied || derive_ids(batch.size))
        end
      end

      # MySQL only - it doesn't give us the inserted rows back for free.
      def supplied_ids(batch)
        ids = batch.map { |row| row[:id] || row['id'] }
        return nil if ids.all?(&:nil?)
        raise ArgumentError, 'rows must all supply an id or none of them' unless ids.none?(&:nil?)

        cast_ids(ids)
      end

      def cast_ids(ids)
        type = model.type_for_attribute('id')
        ids.map { |id| type.cast(id) }
      end

      def derive_ids(count)
        first = select_integer('SELECT LAST_INSERT_ID()')
        step = select_integer('SELECT @@auto_increment_increment')
        Array.new(count) { |i| first + (i * step) }
      end

      def select_integer(sql)
        model.connection.select_value(sql).to_i
      end

      def fetch_rows(ids)
        relation = model.unscoped.where(id: ids).select(*fetched)
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
