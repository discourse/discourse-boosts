# frozen_string_literal: true

RSpec.describe DiscourseBoosts::ReviewableBoost do
  fab!(:admin)
  fab!(:user)
  fab!(:post_author, :user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
  fab!(:boost) { Fabricate(:boost, post: post, user: user) }

  describe "#build_combined_actions" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "builds agree and disagree actions when pending" do
      actions = reviewable.actions_for(admin.guardian)
      agree_bundle = actions.bundles.find { |b| b.id.include?("agree") }
      expect(agree_bundle).to be_present
    end

    it "builds delete and ignore in the disagree bundle" do
      actions = reviewable.actions_for(admin.guardian)

      expect(actions.has?(:delete_and_ignore)).to eq(true)
      expect(actions.has?(:delete_and_agree)).to eq(false)
    end

    it "hides delete actions when the boost post was deleted" do
      boost.update_column(:post_id, -1)

      actions = reviewable.actions_for(admin.guardian)

      expect(actions.has?(:ignore)).to eq(true)
      expect(actions.has?(:agree_and_delete)).to eq(false)
      expect(actions.has?(:delete_and_ignore)).to eq(false)
    end

    it "hides delete actions when the boost post is trashed" do
      post.trash!(admin)

      actions = reviewable.actions_for(admin.guardian)

      expect(actions.has?(:ignore)).to eq(true)
      expect(actions.has?(:agree_and_delete)).to eq(false)
      expect(actions.has?(:delete_and_ignore)).to eq(false)
    end

    it "keeps delete actions for staff when the boost topic is deleted" do
      topic.trash!(admin)

      actions = reviewable.actions_for(admin.guardian)

      expect(actions.has?(:agree_and_delete)).to eq(true)
      expect(actions.has?(:delete_and_ignore)).to eq(true)
    end

    it "hides delete actions for category moderators when the boost topic is deleted" do
      SiteSetting.enable_category_group_moderation = true
      category_moderator = Fabricate(:user)
      group = Fabricate(:group)
      group.add(category_moderator)
      Fabricate(:category_moderation_group, category: topic.category, group: group)
      topic.trash!(admin)

      actions = reviewable.actions_for(category_moderator.guardian)

      expect(actions.has?(:ignore)).to eq(true)
      expect(actions.has?(:agree_and_delete)).to eq(false)
      expect(actions.has?(:delete_and_ignore)).to eq(false)
    end
  end

  describe "#perform_agree_and_delete" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "destroys the boost" do
      boost_id = boost.id
      reviewable.perform(admin, :agree_and_delete)
      expect(DiscourseBoosts::Boost.exists?(boost_id)).to eq(false)
    end
  end

  describe "#perform_disagree" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "keeps the boost" do
      reviewable.perform(admin, :disagree)
      expect(DiscourseBoosts::Boost.exists?(boost.id)).to eq(true)
    end
  end

  describe "#perform_delete_and_ignore" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "ignores the flag and destroys the boost" do
      boost_id = boost.id

      reviewable.perform(admin, :delete_and_ignore)

      expect(reviewable).to be_ignored
      expect(DiscourseBoosts::Boost.exists?(boost_id)).to eq(false)
    end
  end
end
