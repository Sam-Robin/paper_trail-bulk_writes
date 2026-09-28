# frozen_string_literal: true

require 'paper_trail/bulk_writes'
require 'paper_trail/frameworks/rspec'

Time.zone = 'UTC'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |file| require file }

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    ActiveRecord::Base.transaction(joinable: false) do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.after { PaperTrail::BulkWrites.reset_configuration! }
end
