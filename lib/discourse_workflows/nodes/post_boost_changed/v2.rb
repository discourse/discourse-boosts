# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostBoostChanged
        class V2 < V1
          V2_OUTPUT_SCHEMA =
            Schema.merge(
              Schema.document(OUTPUT_SCHEMA.fetch("properties").except("removed_by")),
              Schema::POST_AUTHOR_SCHEMA,
              Schema::ACTOR_SCHEMA,
              Schema.document(
                "booster" => {
                  "type" => "object",
                  "description" => "User whose boost it is",
                  "properties" => Schema::USER_PROPERTIES,
                },
              ),
            ).freeze
          CHANGE_OUTPUT_SCHEMA =
            Schema.document(V2_OUTPUT_SCHEMA.fetch("properties").except("change")).freeze

          description(
            superclass.description.merge(
              version: "2.0",
              palette_visible: false,
              output_contracts: [{ schema: V2_OUTPUT_SCHEMA }],
            ),
          )

          def self.description_for_change(name, change, icon:)
            description.merge(
              name:,
              version: "1.0",
              defaults: {
                icon:,
                color: "orange",
              },
              palette_visible: true,
              event: CHANGES.key(change),
              fixed_changes: [change],
              i18n_scope: "post_boost_changed",
              output_contracts: [{ schema: CHANGE_OUTPUT_SCHEMA }],
              properties: properties.except(:changes),
            )
          end

          def valid?
            fixed_changes = self.class.description[:fixed_changes]
            super && (fixed_changes.nil? || fixed_changes.include?(@change))
          end

          # The booster acts, except when someone else (a moderator) removes the boost.
          def output
            data =
              super.except(:removed_by).merge(
                user: serialize_user(@boost.post.user),
                actor: serialize_user(@removed_by || @boost.user),
                booster: serialize_user(@boost.user),
              )
            self.class.description[:fixed_changes] ? data.except(:change) : data
          end
        end
      end
    end
  end
end
