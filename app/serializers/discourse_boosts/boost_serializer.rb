# frozen_string_literal: true

module DiscourseBoosts
  class BoostSerializer < ::ApplicationSerializer
    attributes :id, :cooked, :can_delete, :can_flag, :user_flag_status, :available_flags

    has_one :user, serializer: ::BasicUserSerializer, embed: :objects

    def can_delete
      scope.user && (object.user_id == scope.user.id || scope.can_review_topic?(object.post.topic))
    end

    def can_flag
      available_flags.present?
    end

    def user_flag_status
      return nil unless scope.user
      reviewable =
        if @options[:reviewables_by_target]
          @options[:reviewables_by_target][object.id]
        else
          Reviewable.find_by(target: object)
        end
      return nil unless reviewable
      score = reviewable.reviewable_scores.find { |s| s.user_id == scope.user.id }
      score&.status_for_database
    end

    def include_user_flag_status?
      scope.user.present?
    end

    def available_flags
      @available_flags ||=
        boost_available_flags.select { |flag_name| scope.can_flag_boost?(object, flag_name) }
    end

    def include_available_flags?
      can_flag
    end

    private

    def boost_available_flags
      @options[:available_flags] ||
        Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:name_key)
    end
  end
end
