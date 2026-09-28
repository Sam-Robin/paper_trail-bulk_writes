# frozen_string_literal: true

# ActiveSupport 7.1 and 8.0 still pass quirks_mode: to JSON.generate, which json 3.0 rejects.
appraise 'rails-7-1-paper-trail-15' do
  gem 'activerecord', '~> 7.1.0'
  gem 'json', '< 3'
  gem 'paper_trail', '~> 15.0'
end

appraise 'rails-7-2-paper-trail-16' do
  gem 'activerecord', '~> 7.2.0'
  gem 'paper_trail', '~> 16.0'
end

appraise 'rails-8-0-paper-trail-17' do
  gem 'activerecord', '~> 8.0.0'
  gem 'json', '< 3'
  gem 'paper_trail', '~> 17.0'
end
