# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class RowSource
      def initialize(scope, tracked:, adapter:)
        @scope = scope
        @tracked = tracked
        @adapter = adapter
      end

      def each_batch(batch_size)
        if scope.is_a?(ActiveRecord::Relation) && !scope.loaded?
          scope.in_batches(of: batch_size) { |relation| yield(rows_for_relation(relation)) }
        else
          scope.to_a.each_slice(batch_size) { |records| yield(loaded_rows(records)) }
        end
      end

      private

      attr_reader :scope, :tracked, :adapter

      def rows_for_relation(relation)
        return loaded_rows(relation.to_a) if adapter.meta.any?

        relation.pluck(:id, *tracked).map do |id, *values|
          [id, tracked.zip(values).to_h, {}]
        end
      end

      def loaded_rows(records)
        records.map do |record|
          [record.id, tracked.index_with { |name| record.read_attribute(name) }, adapter.meta_for(record)]
        end
      end
    end
  end
end
