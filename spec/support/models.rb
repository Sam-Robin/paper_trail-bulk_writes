# frozen_string_literal: true

class Widget < ActiveRecord::Base
  include PaperTrail::BulkWrites::Model

  has_paper_trail
  enum :status, { draft: 'draft', active: 'active', filled: 'filled' }
end

class Gadget < Widget
end

class Ticket < ActiveRecord::Base
  include PaperTrail::BulkWrites::Model

  has_paper_trail only: [:priority]
end

class ContractVersion < PaperTrail::Version
  self.table_name = 'contract_versions'
end

class Contract < ActiveRecord::Base
  include PaperTrail::BulkWrites::Model

  has_paper_trail versions: { class_name: 'ContractVersion' },
                  meta: { account_id: :account_id, label: ->(contract) { "contract-#{contract.title}" } }
end

class Note < ActiveRecord::Base
  include PaperTrail::BulkWrites::Model

  has_paper_trail ignore: %i[views updated_at], skip: [:secret]
end

class PlainRecord < ActiveRecord::Base
  include PaperTrail::BulkWrites::Model
end
