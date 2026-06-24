# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseBoosts::ReviewableBoostSerializer do
  fab!(:admin)
  fab!(:post_author, :user)
  fab!(:topic)
  fab!(:post) do
    Fabricate(:post, topic: topic, post_number: 2, user: post_author)
  end
  fab!(:boost) { Fabricate(:boost, post: post) }
  fab!(:reviewable) do
    DiscourseBoosts::ReviewableBoost.needs_review!(
      created_by: admin,
      target: boost,
      topic: post.topic,
      target_created_by: boost.user,
      reviewable_by_moderator: true,
      payload: {
        boost_cooked: boost.cooked
      }
    )
  end

  it "links to the boosted post" do
    json =
      described_class.new(
        reviewable,
        scope: admin.guardian,
        root: false
      ).as_json

    expect(json[:target_url]).to eq(post.url)
  end
end
