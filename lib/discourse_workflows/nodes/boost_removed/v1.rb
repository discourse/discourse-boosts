# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module BoostRemoved
        class V1 < PostBoostChanged::V2
          description(
            PostBoostChanged::V2.description_for_change(
              "trigger:boost_removed",
              "removed",
              icon: "trash-can",
            ),
          )
        end
      end
    end
  end
end
