# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Delete
      include Versioned
      include Scoped

      def initialize(scope:, whodunnit: nil, batch_size: nil)
        @scope = scope
        @whodunnit = whodunnit
        @batch_size = batch_size || default_batch_size
      end

      def call
        return 0 if model.nil?

        written = 0
        rows.each_batch(batch_size) { |batch| written += write(batch) }
        written
      end

      private

      attr_reader :scope, :whodunnit, :batch_size

      def write(batch)
        ids = batch.map(&:first)
        return 0 if ids.empty?

        model.transaction do
          model.where(id: ids).delete_all
          adapter.insert(batch.map { |id, previous, extra| version_row(id, previous, extra) })
        end

        ids.size
      end

      def version_row(id, previous, extra)
        adapter.build_row(
          id: id,
          event: 'destroy',
          object_changes: previous.transform_values { |was| [was, nil] },
          extra: extra
        )
      end

      def tracked
        @tracked ||= adapter.tracked(model.column_names)
      end
    end
  end
end
