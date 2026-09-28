# frozen_string_literal: true

require 'rubocop'
require_relative '../../rubocop/cop/paper_trail/bulk_writes/no_bulk_write_on_audited_model'

module PaperTrail
  module BulkWrites
    module RuboCop
      CONFIG_DEFAULT = File.expand_path('../../../config/default.yml', __dir__)

      class Inject
        def self.defaults!
          hash = ::RuboCop::ConfigLoader.send(:load_yaml_configuration, CONFIG_DEFAULT)
          config = ::RuboCop::Config.new(hash, CONFIG_DEFAULT)
          puts "configuration from #{CONFIG_DEFAULT}" if ::RuboCop::ConfigLoader.debug?
          config = ::RuboCop::ConfigLoader.merge_with_default(config, CONFIG_DEFAULT)
          ::RuboCop::ConfigLoader.instance_variable_set(:@default_configuration, config)
        end
      end
    end
  end
end

PaperTrail::BulkWrites::RuboCop::Inject.defaults!
