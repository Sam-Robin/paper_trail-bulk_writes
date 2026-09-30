# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'appraisal'
gem 'irb'
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rubocop', '~> 1.21'
gem 'rubocop-rspec'
gem 'sqlite3'

group :postgres, optional: true do
  gem 'pg'
end

group :mysql, optional: true do
  gem 'mysql2'
end
