# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Update
      include Versioned
      include Scoped

      def initialize(scope:, attributes:, whodunnit: nil, batch_size: nil, touch: true)
        @scope = scope
        @attributes = attributes.stringify_keys
        @whodunnit = whodunnit
        @batch_size = batch_size || default_batch_size
        @touch = touch
      end

      def call
        return 0 if model.nil?

        written = 0
        rows.each_batch(batch_size) { |batch| written += write(batch) }
        written
      end

      private

      attr_reader :scope, :attributes, :whodunnit, :batch_size, :touch

      def write(batch)
        ids = batch.map(&:first)
        return 0 if ids.empty?

        model.transaction do
          model.where(id: ids).update_all(write_attributes)
          adapter.insert(batch.filter_map { |id, previous, extra| version_row(id, previous, extra) })
        end

        ids.size
      end

      def write_attributes
        @write_attributes ||= if touch
                                attributes.merge('updated_at' => model.current_time_from_proper_timezone)
                              else
                                attributes
                              end
      end

      def version_row(id, previous, extra)
        changes = object_changes_for(previous)
        return if changes.empty?

        adapter.build_row(id: id, event: 'update', object_changes: changes, extra: extra)
      end

      def tracked
        @tracked ||= adapter.tracked(write_attributes.keys)
      end

      def new_values
        @new_values ||= tracked.index_with { |name| model.type_for_attribute(name).cast(write_attributes[name]) }
      end

      def object_changes_for(previous)
        tracked.each_with_object({}) do |name, changes|
          was = previous[name]
          now = new_values[name]
          changes[name] = [was, now] unless was == now
        end
      end
    end
  end
end
