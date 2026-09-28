# frozen_string_literal: true

module PaperTrail
  module BulkWrites
    class Configuration
      DEFAULT_BATCH_SIZE = 1_000

      attr_accessor :batch_size

      def initialize
        @batch_size = DEFAULT_BATCH_SIZE
      end
    end
  end
end
