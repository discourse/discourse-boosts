# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module RemoveBoost
        class V1 < DiscourseWorkflows::NodeType
          include PostBoosting

          description(
            PostBoosting.description(
              name: "action:remove_boost",
              icon: "trash-can",
              changed: "False when the actor hadn't boosted the post",
            ),
          )

          private

          def change_post(exec_ctx, item_index)
            post, actor = find_post_and_actor(exec_ctx, item_index)
            boost = boost_of(actor, post)
            changed = boost.present? && destroy_boost(boost, actor, item_index)

            post_output(post, actor, changed:).merge(previous_text: boost&.raw)
          end

          # The service doesn't say whether it removed anything, so lock the boost first: a concurrent removal
          # that already deleted it raises instead of being reported twice.
          def destroy_boost(boost, actor, item_index)
            ::DiscourseBoosts::Boost.transaction do
              boost.lock!
              ::DiscourseBoosts::Boost::Destroy.call(
                params: {
                  boost_id: boost.id,
                },
                guardian: actor.guardian,
              ) do
                on_success { true }
                on_failure { raise_cannot_boost!(actor, item_index) }
              end
            end
          rescue ActiveRecord::RecordNotFound
            false
          end
        end
      end
    end
  end
end
