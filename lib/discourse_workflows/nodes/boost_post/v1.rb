# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module BoostPost
        class V1 < DiscourseWorkflows::NodeType
          include PostBoosting

          IF_EXISTS_OPTIONS = %w[keep replace].freeze

          description(
            PostBoosting.description(
              name: "action:boost_post",
              icon: "rocket",
              changed:
                "False when the actor's boost already had this text, or another one kept by if_exists",
              properties: {
                text: {
                  type: :string,
                  required: true,
                },
                if_exists: {
                  type: :options,
                  required: true,
                  options: IF_EXISTS_OPTIONS,
                  default: "keep",
                },
              },
              output: {
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
              },
            ),
          )

          private

          def change_post(exec_ctx, item_index)
            post, actor = find_post_and_actor(exec_ctx, item_index)
            text = exec_ctx.get_node_parameter("text", item_index)
            existing_boost = boost_of(actor, post)
            previous_text = existing_boost&.raw

            boost =
              if existing_boost.nil?
                save_boost(::DiscourseBoosts::Boost::Create, post, actor, text, item_index)
              elsif exec_ctx.get_node_parameter("if_exists", item_index) == "replace"
                save_boost(::DiscourseBoosts::Boost::Update, post, actor, text, item_index)
              else
                existing_boost
              end

            post_output(post, actor, changed: boost.raw != previous_text).merge(
              boost: {
                id: boost.id,
                text: boost.raw,
              },
              previous_text:,
            )
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
        end
      end
    end
  end
end
