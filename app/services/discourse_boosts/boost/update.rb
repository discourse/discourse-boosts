# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Update
    include Service::Base

    params do
      attribute :post_id, :integer
      attribute :raw, :string

      before_validation { self.raw = raw.to_s.strip }

      validates :post_id, presence: true
      validates :raw, presence: true
    end

    model :post
    model :boost
    policy :can_boost_post
    policy :not_blocked_by_watched_words
    model :processed_raw

    step :update_boost

    only_if(:boost_changed?) do
      step :trigger_boost_updated
      step :publish_change
    end

    private

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def fetch_boost(post:, guardian:)
      DiscourseBoosts::Boost.find_by(post:, user: guardian.user)
    end

    def can_boost_post(guardian:, post:)
      guardian.can_boost_post?(post)
    end

    def not_blocked_by_watched_words(params:)
      !WordWatcher.new(params.raw).should_block?
    end

    def fetch_processed_raw(params:)
      WordWatcher.apply_to_text(params.raw)
    end

    def update_boost(boost:, processed_raw:)
      fail!(boost.errors.full_messages.join(", ")) if !boost.update(raw: processed_raw)
    end

    def boost_changed?(boost:)
      boost.saved_change_to_raw?
    end

    def trigger_boost_updated(boost:)
      DiscourseEvent.trigger(:boost_updated, boost, boost.raw_before_last_save)
    end

    def publish_change(post:, boost:)
      DiscourseBoosts::Boost.publish_remove(post, boost.id)
      DiscourseBoosts::Boost.publish_add(post, boost)
    end
  end
end
