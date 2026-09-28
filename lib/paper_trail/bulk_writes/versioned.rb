# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    module Versioned
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def call(...)
          new(...).call
        end
      end

      private

      def adapter
        @adapter ||= Adapter.new(model, whodunnit: whodunnit)
      end

      def default_batch_size
        BulkWrites.configuration.batch_size
      end
    end
  end
end
