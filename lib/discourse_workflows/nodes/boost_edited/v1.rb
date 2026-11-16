# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module BoostEdited
        class V1 < PostBoostChanged::V2
          description(
            PostBoostChanged::V2.description_for_change(
              "trigger:boost_edited",
              "replaced",
              icon: "pencil",
            ),
          )
        end
      end
    end
  end
end
