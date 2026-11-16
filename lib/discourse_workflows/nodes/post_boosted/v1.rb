# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module PostBoosted
        class V1 < PostBoostChanged::V2
          description(
            PostBoostChanged::V2.description_for_change(
              "trigger:post_boosted",
              "added",
              icon: "rocket",
            ),
          )
        end
      end
    end
  end
end
