# frozen_string_literal: true

# Add DiscourseBoosts::Boost to the applies_to array of flags that support
# boost flagging. This runs after the core 003_flags fixture.
#
# Excluded:
#   - like (not a flag)
#   - notify_user (boosts only support reviewable-based flags and companion
#     PMs for notify_moderators/illegal)
Flag
  .where("'Post' = ANY(applies_to)")
  .where.not(id: PostActionType::LIKE_POST_ACTION_ID)
  .where.not(name_key: "notify_user")
  .each do |flag|
    next if flag.applies_to.include?("DiscourseBoosts::Boost")
    flag.update!(applies_to: flag.applies_to + ["DiscourseBoosts::Boost"])
  end
