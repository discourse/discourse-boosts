# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      # Boost post and Remove boost change the actor's own boost on a post through the services behind the
      # boost button, so they follow its rules.
      module PostBoosting
        include PostChangeAction

        PREVIOUS_TEXT = {
          "previous_text" => {
            "type" => %w[string null],
            "description" => "The actor's boost text before",
          },
        }.freeze

        def self.description(name:, icon:, changed:, properties: {}, output: {})
          PostChangeAction.description(
            name:,
            icon:,
            color: "orange",
            i18n_scope: "post_boosting",
            changed:,
            properties:,
            output: {
              **output,
              **PREVIOUS_TEXT,
            },
          ).merge(
            available: -> { SiteSetting.discourse_boosts_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_boosts",
          )
        end

        private

        def find_post_and_actor(exec_ctx, item_index)
          [
            ::Post.find(exec_ctx.get_node_parameter("post_id", item_index)),
            exec_ctx.actor_from_parameter("actor_username", item_index),
          ]
        end

        def boost_of(actor, post)
          ::DiscourseBoosts::Boost.find_by(post:, user: actor)
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
