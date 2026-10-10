# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostBoostChanged
        class V1 < DiscourseWorkflows::NodeType
          CHANGES = {
            boost_created: "added",
            boost_updated: "replaced",
            boost_destroyed: "removed",
          }.freeze

          OUTPUT_SCHEMA =
            Schema.merge(
              Schema::POST_SCHEMA,
              Schema::TOPIC_LIST_ITEM_SCHEMA,
              Schema::USER_SCHEMA,
              Schema.document(
                "change" => {
                  "type" => "string",
                  "enum" => CHANGES.values,
                },
                "boost" => {
                  "type" => "object",
                  "properties" => {
                    "id" => {
                      "type" => "integer",
                    },
                    "text" => {
                      "type" => "string",
                    },
                  },
                },
                "previous_text" => {
                  "type" => %w[string null],
                },
                "removed_by" => {
                  "type" => %w[object null],
                  "properties" => Schema::USER_PROPERTIES,
                },
              ),
            ).freeze

          description(
            name: "trigger:post_boost_changed",
            version: "1.0",
            defaults: {
              icon: "rocket",
              color: "orange",
            },
            group: "discourse_triggers",
            event: CHANGES.keys,
            available: -> { SiteSetting.discourse_boosts_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_boosts",
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              changes: {
                type: :multi_options,
                required: false,
                default: [],
                options: CHANGES.values,
              },
              **TOPIC_SCOPE_FILTER_PROPERTIES,
            },
          )

          def self.from_event(event_name, boost, *args)
            case event_name
            when :boost_updated
              new(event_name, boost, previous_text: args.first)
            when :boost_destroyed
              new(event_name, boost, removed_by: args.first)
            else
              new(event_name, boost)
            end
          end

          def initialize(event_name, boost, previous_text: nil, removed_by: nil)
            super(parameters: {})
            @change = CHANGES[event_name]
            @boost = boost
            @previous_text = previous_text
            @removed_by = removed_by
          end

          def valid?
            @change.present? && @boost.post&.topic.present? && @boost.user.present?
          end

          def user_id
            @boost.user_id
          end

          def output
            {
              change: @change,
              boost: {
                id: @boost.id,
                text: @boost.raw,
              },
              previous_text: @previous_text,
              removed_by: (serialize_user(@removed_by) if @removed_by),
              post: serialize_post(@boost.post),
              topic: topic_data(@boost.post.topic),
              user: serialize_user(@boost.user),
            }
          end

          def matches?(trigger_ctx)
            matches_changes?(trigger_ctx, @change) &&
              matches_topic_filters?(@boost.post.topic, trigger_ctx)
          end
        end
      end
    end
  end
end
