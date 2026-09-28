# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    module Scoped
      private

      def model
        return @model if defined?(@model)

        @model = BulkWrites.model_for(scope)
      end

      def rows
        RowSource.new(scope, tracked: tracked, adapter: adapter)
      end
    end
  end
end
