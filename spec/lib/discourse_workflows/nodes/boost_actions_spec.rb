# frozen_string_literal: true

RSpec.shared_context "with a post to boost" do
  fab!(:post)
  fab!(:actor, :user)

  before { SiteSetting.discourse_boosts_enabled = true }

  def run_node(**rest)
    execute_node(
      configuration: {
        "post_id" => post.id.to_s,
        "actor_username" => actor.username,
        **rest.stringify_keys,
      },
    )
  end

  def boost(raw)
    DiscourseBoosts::Boost::Create.call(
      params: {
        post_id: post.id,
        raw:,
      },
      guardian: actor.guardian,
    )
  end

  def current_boost
    DiscourseBoosts::Boost.find_by(post:, user: actor)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::BoostPost::V1 do
  include_context "with a post to boost"

  it "boosts the post as the actor", :aggregate_failures do
    result = run_node(text: "🚀")

    expect(result).to include(
      "post" => include("id" => post.id),
      "actor" => include("id" => actor.id),
      "boost" => {
        "id" => current_boost.id,
        "text" => "🚀",
      },
      "previous_text" => nil,
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
  end

  it "keeps another boost by default" do
    boost("🎉")

    expect(run_node(text: "🚀")).to include("changed" => false, "boost" => include("text" => "🎉"))
  end

  it "replaces another boost when asked" do
    boost("🎉")

    expect(run_node(text: "🚀", if_exists: "replace")).to include(
      "changed" => true,
      "previous_text" => "🎉",
      "boost" => include("text" => "🚀"),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RemoveBoost::V1 do
  include_context "with a post to boost"

  it "removes the actor's boost", :aggregate_failures do
    boost("🎉")

    result = run_node

    expect(result).to include("changed" => true, "previous_text" => "🎉")
    expect(result).to match_node_output_schema(described_class)
    expect(current_boost).to be_nil
  end

  it "reports nothing changed when a concurrent request removed the boost first",
     :aggregate_failures do
    boost("🎉")
    DiscourseBoosts::Boost.any_instance.stubs(:lock!).raises(ActiveRecord::RecordNotFound)

    events =
      DiscourseEvent.track_events(:boost_destroyed) do
        expect(run_node).to include("changed" => false)
      end

    expect(events).to be_empty
  end

  it "reports nothing changed when the actor hadn't boosted the post" do
    expect(run_node).to include("changed" => false, "previous_text" => nil)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostBoosted::V1 do
  fab!(:admin)
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author) }
  fab!(:booster, :user)

  before { SiteSetting.discourse_boosts_enabled = true }

  def trigger_for(trigger_class, &)
    event = DiscourseEvent.track_events(&).find { it[:event_name].to_s.start_with?("boost_") }
    trigger_class.from_event(event[:event_name], *event[:params])
  end

  it "reports each change through its own trigger, with who acted", :aggregate_failures do
    params = { post_id: post.id, raw: "🎉" }
    created = nil
    added =
      trigger_for(described_class) do
        created = DiscourseBoosts::Boost::Create.call(params:, guardian: booster.guardian).boost
      end
    edited =
      trigger_for(DiscourseWorkflows::Nodes::BoostEdited::V1) do
        DiscourseBoosts::Boost::Update.call(
          params: params.merge(raw: "🧩"),
          guardian: booster.guardian,
        )
      end
    removed =
      trigger_for(DiscourseWorkflows::Nodes::BoostRemoved::V1) do
        DiscourseBoosts::Boost::Destroy.call(
          params: {
            boost_id: created.id,
          },
          guardian: admin.guardian,
        )
      end

    expect(added).to be_valid
    expect(added.output).to include(
      user: include(id: author.id),
      actor: include(id: booster.id),
      booster: include(id: booster.id),
      boost: include(text: "🎉"),
    )
    expect(added.output).not_to have_key(:change)
    expect(added.output).to match_node_output_schema(described_class)

    expect(edited).to be_valid
    expect(edited.output).to include(previous_text: "🎉", boost: include(text: "🧩"))

    expect(removed).to be_valid
    expect(removed.output).to include(
      actor: include(id: admin.id),
      booster: include(id: booster.id),
    )
    expect(removed.output).to match_node_output_schema(DiscourseWorkflows::Nodes::BoostRemoved::V1)

    expect(described_class.from_event(:boost_destroyed, created, admin)).not_to be_valid
  end

  it "hides the generic trigger from the palette" do
    expect(DiscourseWorkflows::Nodes::PostBoostChanged::V2).not_to be_palette_visible
  end
end
