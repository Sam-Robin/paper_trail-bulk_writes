# frozen_string_literal: true

require 'active_record'
require 'paper_trail'

require_relative 'bulk_writes/version'
require_relative 'bulk_writes/configuration'
require_relative 'bulk_writes/adapter'
require_relative 'bulk_writes/row_source'
require_relative 'bulk_writes/versioned'
require_relative 'bulk_writes/scoped'
require_relative 'bulk_writes/insert'
require_relative 'bulk_writes/update'
require_relative 'bulk_writes/delete'
require_relative 'bulk_writes/model'

module PaperTrail
  module BulkWrites
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end

      def reset_configuration!
        @configuration = Configuration.new
      end

      def model_for(scope)
        scope.is_a?(ActiveRecord::Relation) ? scope.klass : scope.first&.class
      end
    end
  end
end
