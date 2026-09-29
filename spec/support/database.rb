# frozen_string_literal: true

module Database
  ADAPTER = ENV.fetch('DB', 'sqlite')

  def self.connect
    case ADAPTER
    when 'sqlite'
      ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    when 'postgres'
      ActiveRecord::Base.establish_connection(
        ENV['DATABASE_URL'] || 'postgres://postgres:postgres@localhost:5432/paper_trail_bulk_writes_test'
      )
    when 'mysql'
      ActiveRecord::Base.establish_connection(
        ENV['DATABASE_URL'] || 'mysql2://root:root@127.0.0.1:3306/paper_trail_bulk_writes_test'
      )
    else
      raise ArgumentError, "unknown DB=#{ADAPTER}"
    end
  end

  def self.json_type
    ADAPTER == 'postgres' ? :jsonb : :json
  end

  def self.define_schema
    ActiveRecord::Schema.verbose = false

    ActiveRecord::Schema.define do
      create_table :versions, force: true do |t|
        t.string :item_type, null: false
        t.bigint :item_id, null: false
        t.string :item_subtype
        t.string :event, null: false
        t.string :whodunnit
        t.text :object
        t.column :object_changes, Database.json_type
        t.datetime :created_at
      end

      create_table :contract_versions, force: true do |t|
        t.string :item_type, null: false
        t.bigint :item_id, null: false
        t.string :event, null: false
        t.string :whodunnit
        t.column :object_changes, Database.json_type
        t.bigint :account_id
        t.string :label
        t.datetime :created_at
      end

      create_table :widgets, force: true do |t|
        t.string :type
        t.string :name
        t.string :status, default: 'draft', null: false
        t.integer :quantity, default: 0, null: false
        t.timestamps
      end

      create_table :tickets, force: true do |t|
        t.bigint :account_id
        t.string :title
        t.string :priority
        t.timestamps
      end

      create_table :contracts, force: true do |t|
        t.bigint :account_id
        t.string :title, null: false
        t.string :state
        t.text :notes
        t.timestamps
      end

      create_table :notes, force: true do |t|
        t.string :body
        t.integer :views, default: 0, null: false
        t.string :secret
        t.timestamps
      end

      create_table :plain_records, force: true do |t|
        t.string :name
        t.timestamps
      end
    end
  end
end

Database.connect
Database.define_schema
