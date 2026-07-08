# frozen_string_literal: true

# name: discourse-boosts
# about: Allows users to add freeform micro-reactions (boosts) to posts.
# version: 0.1
# authors: discourse
# url: https://github.com/discourse/discourse-boosts

enabled_site_setting :discourse_boosts_enabled

register_asset "stylesheets/common/discourse-boosts.scss"

register_svg_icon "rocket"
register_svg_icon "trash-can"
register_svg_icon "flag"

module ::DiscourseBoosts
  PLUGIN_NAME = "discourse-boosts"
end

require_relative "lib/discourse_boosts/engine"

after_initialize do
  reloadable_patch do |plugin|
    Post.prepend DiscourseBoosts::PostExtension
    UserOption.prepend DiscourseBoosts::UserOptionExtension
    Reviewable.prepend DiscourseBoosts::ReviewableExtension
    TopicView.prepend DiscourseBoosts::TopicViewExtension
  end

  Discourse::Application.routes.append { mount DiscourseBoosts::Engine, at: "/" }

  add_to_class(:guardian, :can_boost_post?) do |post|
    authenticated? && post && can_see_post?(post) && !user.silenced? && !post.topic&.archived? &&
      !post.trashed? && post.user_id.present? && !is_my_own?(post)
  end

  add_to_class(
    :guardian,
    :can_flag_boost?
  ) do |boost, flag_type, take_action: false, queue_for_review: false|
    return false if !authenticated? || boost.blank?

    post = boost.post
    return false if post.blank? || !can_see?(post) || post.hidden?
    return false if user.silenced? || boost.user_id == user.id
    return false if !SiteSetting.allow_flagging_staff? && boost.user&.staff?
    return false if (take_action || queue_for_review) && !is_staff?

    post_action_type_view = PostActionTypeView.new
    flag_name =
      case flag_type
      when Flag
        flag_type.name_key&.to_sym
      when String, Symbol
        flag_type.to_sym
      else
        post_action_type_view.types[flag_type.to_i] if flag_type.present?
      end
    return false if flag_name.blank?

    flag_id = post_action_type_view.flag_types[flag_name]
    return false if flag_id.blank?
    if !post_action_type_view.applies_to[flag_id]&.include?(
         "DiscourseBoosts::Boost"
       )
      return false
    end
    if post_action_type_view.disabled_flag_types.keys.include?(flag_name)
      return false
    end

    user.in_any_groups?(SiteSetting.flag_post_allowed_groups_map) ||
      post.topic&.private_message? ||
      (
        flag_name == :illegal &&
          SiteSetting.allow_all_users_to_flag_illegal_content
      )
  end

  TopicView.on_preload do |topic_view|
    if SiteSetting.discourse_boosts_enabled
      topic_view.instance_variable_set(:@posts, topic_view.posts.includes(boosts: :user))

      topic_view.boosts_available_flags =
        Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:name_key)
    end
  end

  add_to_serializer(
    :post,
    :boosts,
    include_condition: -> do
      SiteSetting.discourse_boosts_enabled && object.association(:boosts).loaded?
    end,
  ) do
    boosts = object.boosts

    if scope.user
      ignored_user_ids = scope.user.ignored_user_ids
      if ignored_user_ids.present?
        boosts = boosts.reject { |b| ignored_user_ids.include?(b.user_id) && !b.user&.staff? }
      end
    end

    reviewables_by_target =
      if scope.user && @topic_view
        @topic_view.boosts_reviewables_by_target ||=
          begin
            all_boost_ids =
              @topic_view.posts.flat_map do |p|
                p.association(:boosts).loaded? ? p.boosts.map(&:id) : []
              end
            if all_boost_ids.present?
              Reviewable
                .includes(:reviewable_scores)
                .where(target_type: "DiscourseBoosts::Boost", target_id: all_boost_ids)
                .index_by(&:target_id)
            else
              {}
            end
          end
      else
        {}
      end

    available_flags =
      @topic_view&.boosts_available_flags ||
        Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:name_key)

    boosts.map do |boost|
      DiscourseBoosts::BoostSerializer.new(
        boost,
        scope: scope,
        root: false,
        reviewables_by_target: reviewables_by_target,
        available_flags: available_flags,
      ).as_json
    end
  end

  add_to_serializer(
    :post,
    :can_boost,
    include_condition: -> do
      SiteSetting.discourse_boosts_enabled && object.association(:boosts).loaded?
    end,
  ) do
    scope.can_boost_post?(object) && object.boosts.none? { |b| b.user_id == scope.user.id } &&
      object.boosts.size < SiteSetting.discourse_boosts_max_per_post
  end

  UserUpdater::OPTION_ATTR.push(:boost_notifications_level)

  add_to_serializer(:user_option, :boost_notifications_level) { object.boost_notifications_level }

  register_reviewable_type DiscourseBoosts::ReviewableBoost
  DiscoursePluginRegistry.register_flag_applies_to_type("DiscourseBoosts::Boost", self)
  register_seedfu_fixtures(Rails.root.join("plugins/discourse-boosts/db/fixtures"))

  register_notification_consolidation_plan(
    DiscourseBoosts::NotificationConsolidation.boosted_by_multiple_users_plan,
  )
end
