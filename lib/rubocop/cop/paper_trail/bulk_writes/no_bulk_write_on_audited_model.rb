# frozen_string_literal: true

module RuboCop
  module Cop
    module PaperTrail
      module BulkWrites
        # Flags update_all / delete_all / insert_all / upsert_all on a model listed in `Models`.
        # Those writes skip callbacks, so PaperTrail records nothing. Use the audited_* helpers
        # from PaperTrail::BulkWrites::Model instead.
        #
        # @example
        #   # bad
        #   Shift.where(id: ids).update_all(status: :filled)
        #   Shift.where(id: ids).delete_all
        #   Shift.insert_all(rows)
        #
        #   # good
        #   Shift.where(id: ids).audited_update_all(attributes: { status: :filled })
        #   Shift.where(id: ids).audited_delete_all
        #   Shift.audited_insert_all(rows)
        class NoBulkWriteOnAuditedModel < Base
          MSG = '`%<method>s` on %<model>s skips callbacks, so PaperTrail records no version. ' \
                'Use `%<replacement>s` (include `PaperTrail::BulkWrites::Model` on the model), ' \
                'or `%<callback_alternative>s` when you want the record callbacks to run too.'

          REPLACEMENTS = {
            update_all: 'audited_update_all',
            delete_all: 'audited_delete_all',
            insert_all: 'audited_insert_all',
            insert_all!: 'audited_insert_all',
            upsert_all: 'audited_insert_all'
          }.freeze

          CALLBACK_ALTERNATIVES = {
            update_all: 'each(&:update!)',
            delete_all: 'destroy_all',
            insert_all: 'create!',
            insert_all!: 'create!',
            upsert_all: 'create!'
          }.freeze

          RESTRICT_ON_SEND = REPLACEMENTS.keys.freeze

          def on_send(node)
            model = audited_chain_root(node)
            return unless model

            add_offense(node, message: message_for(node.method_name, model))
          end

          private

          def message_for(method, model)
            format(
              MSG,
              method: method,
              model: model,
              replacement: REPLACEMENTS.fetch(method),
              callback_alternative: CALLBACK_ALTERNATIVES.fetch(method)
            )
          end

          def audited_chain_root(node)
            receiver = node.receiver

            while receiver
              return unless receiver.send_type? || receiver.const_type?

              break if receiver.const_type?

              receiver = receiver.receiver
            end

            return unless receiver

            name = receiver.source.delete_prefix('::')
            name if audited_models.include?(name)
          end

          def audited_models
            @audited_models ||= Array(cop_config['Models']).map(&:to_s)
          end
        end
      end
    end
  end
end
