# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::Update do
  before { SiteSetting.discourse_boosts_enabled = true }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:raw) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post)
    fab!(:boost) { Fabricate(:boost, post:, user: acting_user, raw: "🎉") }

    let(:params) { { post_id: post.id, raw: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:raw) { "🧩 certified" }
    let(:messages) { MessageBus.track_publish("/topic/#{post.topic_id}") { result } }

    context "when contract is invalid" do
      let(:raw) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when the user has not boosted the post" do
      fab!(:acting_user, :user)
      fab!(:boost) { Fabricate(:boost, post:) }

      it { is_expected.to fail_to_find_a_model(:boost) }
    end

    context "when user cannot boost the post" do
      before { post.topic.update!(archived: true) }

      it { is_expected.to fail_a_policy(:can_boost_post) }
    end

    context "when raw contains a blocked watched word" do
      before { Fabricate(:watched_word, word: "badword", action: WatchedWord.actions[:block]) }

      let(:raw) { "badword" }

      it { is_expected.to fail_a_policy(:not_blocked_by_watched_words) }
    end

    context "when raw is too long" do
      let(:raw) { "this note is way too long for a boost" }

      it { is_expected.to fail_a_step(:update_boost) }
    end

    context "when raw is unchanged" do
      let(:raw) { "🎉" }

      it "does not announce anything" do
        events = DiscourseEvent.track_events(:boost_updated) { result }

        expect(result).to run_successfully
        expect(events).to be_empty
        expect(messages).to be_empty
      end
    end

    context "when everything's ok" do
      it "updates the boost and announces the change" do
        events = DiscourseEvent.track_events(:boost_updated) { result }

        expect(result).to run_successfully
        expect(boost.reload).to have_attributes(raw: "🧩 certified", cooked: include("certified"))
        expect(events.pluck(:params)).to contain_exactly([boost, "🎉"])
      end

      it "replaces the boost for clients" do
        expect(messages.map { |message| message.data[:type] }).to eq(%i[boost_removed boost_added])
      end
    end
  end
end
