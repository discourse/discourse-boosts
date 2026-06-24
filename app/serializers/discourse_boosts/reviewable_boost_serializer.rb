# frozen_string_literal: true

module DiscourseBoosts
  class ReviewableBoostSerializer < ReviewableSerializer
    payload_attributes :boost_cooked

    def target_url
      object.target&.post&.url
    end

    def created_from_flag?
      true
    end
  end
end
