# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Adapter
      def initialize(model, whodunnit:)
        @model = model
        @whodunnit = whodunnit
      end

      def tracked(candidates)
        tracked = candidates.map(&:to_s) - ignored
        only.any? ? tracked & only : tracked
      end

      def meta
        @meta ||= versioned? ? model.paper_trail_options[:meta].to_h : {}
      end

      def meta_for(record)
        meta.transform_values do |value|
          next value.call(record) if value.respond_to?(:call)
          next record.send(value) if value.is_a?(Symbol)

          value
        end
      end

      def build_row(id:, event:, object_changes:, extra:, subtype: nil)
        row = {
          item_type: model.base_class.name,
          item_id: id,
          event: event,
          whodunnit: whodunnit,
          object_changes: serialize(object_changes),
          created_at: Time.current
        }
        row[:item_subtype] = subtype || default_subtype if subtype_column?
        row.merge(extra)
      end

      def insert(rows)
        return unless versioned? && rows.any?

        version_class.insert_all(rows)
      end

      private

      attr_reader :model, :whodunnit

      def versioned?
        model.respond_to?(:paper_trail_options)
      end

      def version_class
        model.reflect_on_association(model.versions_association_name).klass
      end

      def subtype_column?
        versioned? && version_class.column_names.include?('item_subtype')
      end

      def default_subtype
        model.name unless model == model.base_class
      end

      def serialize(object_changes)
        return object_changes if !versioned? || json_column?

        PaperTrail.serializer.dump(object_changes)
      end

      def json_column?
        return @json_column if defined?(@json_column)

        @json_column = %i[json jsonb].include?(version_class.type_for_attribute('object_changes').type)
      end

      def ignored
        @ignored ||= versioned? ? option_names(:ignore) + option_names(:skip) : []
      end

      def only
        @only ||= versioned? ? option_names(:only) : []
      end

      def option_names(key)
        Array(model.paper_trail_options[key]).grep_v(Hash).map(&:to_s)
      end
    end
  end
end
