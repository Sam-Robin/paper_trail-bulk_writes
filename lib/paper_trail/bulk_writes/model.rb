# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    module Model
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def audited_insert_all(rows, whodunnit: PaperTrail.request.whodunnit)
          Insert.call(model: self, rows: rows, whodunnit: whodunnit)
        end

        def audited_update_all(attributes:, whodunnit: PaperTrail.request.whodunnit, touch: true)
          Update.call(scope: all, attributes: attributes, whodunnit: whodunnit, touch: touch)
        end

        def audited_delete_all(whodunnit: PaperTrail.request.whodunnit)
          Delete.call(scope: all, whodunnit: whodunnit)
        end
      end
    end
  end
end
