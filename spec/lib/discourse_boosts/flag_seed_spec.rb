# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Flag seed for DiscourseBoosts::Boost" do
  def run_seed
    load Rails.root.join("plugins", "discourse-boosts", "db", "fixtures", "004_flags.rb")
  end

  def remove_boost_from_all_flags
    Flag
      .where("'DiscourseBoosts::Boost' = ANY(applies_to)")
      .each { |flag| flag.update!(applies_to: flag.applies_to - ["DiscourseBoosts::Boost"]) }
  end

  before { remove_boost_from_all_flags }

  it "adds DiscourseBoosts::Boost to standard flagging types" do
    run_seed

    %w[off_topic inappropriate spam illegal notify_moderators].each do |name_key|
      expect(Flag.find_by(name_key: name_key).applies_to).to include("DiscourseBoosts::Boost")
    end
  end

  it "does not add DiscourseBoosts::Boost to notify_user" do
    run_seed

    expect(Flag.find_by(name_key: "notify_user").applies_to).not_to include(
      "DiscourseBoosts::Boost",
    )
  end

  it "does not add DiscourseBoosts::Boost to the like action" do
    run_seed

    like = Flag.unscoped.find_by(id: PostActionType::LIKE_POST_ACTION_ID)
    expect(like.applies_to).not_to include("DiscourseBoosts::Boost")
  end

  it "adds DiscourseBoosts::Boost to custom post flags" do
    custom_flag =
      Flag.create!(
        name: "custom test flag",
        applies_to: %w[Post],
        enabled: true,
        notify_type: false,
        auto_action_type: false,
      )

    run_seed

    expect(custom_flag.reload.applies_to).to include("DiscourseBoosts::Boost")
  ensure
    custom_flag&.destroy!
  end

  it "is idempotent" do
    run_seed
    run_seed

    spam_flag = Flag.find_by(name_key: "spam")
    expect(spam_flag.applies_to.count("DiscourseBoosts::Boost")).to eq(1)
  end
end
