# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Boost
        class V1 < DiscourseWorkflows::NodeType
          OPERATIONS = %w[add remove].freeze
          IF_EXISTS_OPTIONS = %w[keep replace].freeze
          OUTPUT_SCHEMA = {
            "$schema" => Schema::DRAFT_URI,
            "type" => "object",
            "properties" => {
              "post_id" => {
                "type" => "integer",
              },
              "username" => {
                "type" => "string",
              },
              "boost_id" => {
                "type" => %w[integer null],
              },
              "text" => {
                "type" => %w[string null],
              },
              "previous_text" => {
                "type" => %w[string null],
              },
              "changed" => {
                "type" => "boolean",
              },
            },
          }.freeze

          description(
            name: "action:boost",
            version: "1.0",
            defaults: {
              icon: "rocket",
              color: "orange",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.discourse_boosts_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_boosts",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [{ schema: OUTPUT_SCHEMA }],
            properties: {
              operation: {
                type: :options,
                required: true,
                options: OPERATIONS,
                default: "add",
              },
              post_id: {
                type: :string,
                required: true,
              },
              text: {
                type: :string,
                required: false,
                display_options: {
                  show: {
                    operation: ["add"],
                  },
                },
              },
              if_exists: {
                type: :options,
                required: true,
                options: IF_EXISTS_OPTIONS,
                default: "keep",
                display_options: {
                  show: {
                    operation: ["add"],
                  },
                },
              },
              **actor_property(allow_anonymous: false),
            },
          )

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                wrap(process(exec_ctx, item_index))
              end

            [items]
          end

          private

          def process(exec_ctx, item_index)
            post = ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
            actor = exec_ctx.actor_from_parameter("actor_username", item_index)
            existing_boost = ::DiscourseBoosts::Boost.find_by(post:, user: actor)
            previous_text = existing_boost&.raw

            boost =
              if exec_ctx.get_node_parameter("operation", item_index, default: "add") == "add"
                text = exec_ctx.get_node_parameter("text", item_index)

                if existing_boost.nil?
                  save_boost(::DiscourseBoosts::Boost::Create, post, actor, text, item_index)
                elsif exec_ctx.get_node_parameter("if_exists", item_index) == "replace"
                  save_boost(::DiscourseBoosts::Boost::Update, post, actor, text, item_index)
                else
                  existing_boost
                end
              elsif existing_boost
                destroy_boost(existing_boost, actor, item_index)
                nil
              end

            {
              post_id: post.id,
              username: actor.username,
              boost_id: boost&.id,
              text: boost&.raw,
              previous_text:,
              changed: boost&.raw != previous_text,
            }
          end

          def save_boost(service, post, actor, text, item_index)
            service.call(params: { post_id: post.id, raw: text }, guardian: actor.guardian) do
              on_success { |boost:| boost }
              on_failed_contract do
                raise_node_error!(I18n.t("discourse_boosts.boost_blank"), item_index:)
              end
              on_failed_policy(:within_post_boost_limit) do
                raise_node_error!(I18n.t("discourse_boosts.post_boost_limit_reached"), item_index:)
              end
              on_model_errors(:boost) do |boost|
                raise_node_error!(boost.errors.full_messages.join(", "), item_index:)
              end
              on_failed_step(:update_boost) { |step| raise_node_error!(step.error, item_index:) }
              on_failure { raise_cannot_boost!(actor, item_index) }
            end
          end

          def destroy_boost(boost, actor, item_index)
            ::DiscourseBoosts::Boost::Destroy.call(
              params: {
                boost_id: boost.id,
              },
              guardian: actor.guardian,
            ) do
              on_success {}
              on_failure { raise_cannot_boost!(actor, item_index) }
            end
          end

          def raise_cannot_boost!(actor, item_index)
            raise_node_error!(
              I18n.t(
                "discourse_boosts.discourse_workflows.boost.cannot_boost",
                username: actor.username,
              ),
              item_index:,
            )
          end
        end
      end
    end
  end
end
