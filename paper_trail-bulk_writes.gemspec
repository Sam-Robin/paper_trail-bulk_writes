# frozen_string_literal: true

require_relative 'lib/paper_trail/bulk_writes/version'

Gem::Specification.new do |spec|
  spec.name = 'paper_trail-bulk_writes'
  spec.version = PaperTrail::BulkWrites::VERSION
  spec.authors = ['Sam Robinson']
  spec.email = ['samrobinsonwork@outlook.com']

  spec.summary = 'PaperTrail versions for update_all, delete_all and insert_all.'
  spec.description = <<~DESC
    Bulk ActiveRecord writes skip callbacks, so PaperTrail records nothing. This gem adds
    audited_update_all, audited_delete_all and audited_insert_all, which run the bulk write
    and insert one version row per record in the same transaction, honouring the model's
    only:, ignore:, skip:, meta: and versions: options. Ships a RuboCop cop that flags
    bare bulk writes on audited models.
  DESC
  spec.homepage = 'https://github.com/Sam-Robin/paper_trail-bulk_writes'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile gemfiles/ Appraisals .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'paper_trail', '>= 15'
end
