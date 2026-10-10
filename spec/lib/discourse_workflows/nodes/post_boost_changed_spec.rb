# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostBoostChanged::V1, discourse_workflows: true do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:booster, :user)
  fab!(:tag)

  before { SiteSetting.discourse_boosts_enabled = true }

  describe "#matches?" do
    it "filters changes, categories, tags, and topics" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag
      trigger = described_class.from_event(:boost_created, Fabricate(:boost, post:, user: booster))

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context(changes: ["removed"]))).to eq(false)
      expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
      expect(trigger.matches?(trigger_context(tag_names: ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context(topic_ids: [topic.id + 1]))).to eq(false)
      expect(
        trigger.matches?(
          trigger_context(
            changes: ["added"],
            category_ids: [category.id],
            tag_names: [tag.name],
            topic_ids: [topic.id],
          ),
        ),
      ).to eq(true)
    end
  end

  describe "event dispatch" do
    it "runs workflows as the booster when a boost is added, replaced and removed by a moderator" do
      graph = build_workflow_graph { |builder| builder.node "boost", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      params = { post_id: post.id, raw: "🎉" }

      boost = DiscourseBoosts::Boost::Create.call(params:, guardian: booster.guardian).boost
      DiscourseBoosts::Boost::Update.call(
        params: params.merge(raw: "🧩"),
        guardian: booster.guardian,
      )
      DiscourseBoosts::Boost::Destroy.call(params: { boost_id: boost.id }, guardian: admin.guardian)

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      data = jobs.pluck("trigger_data")
      expect(
        data.map do |payload|
          [
            payload["change"],
            payload.dig("boost", "text"),
            payload["previous_text"],
            payload.dig("removed_by", "id"),
          ]
        end,
      ).to eq(
        [["added", "🎉", nil, nil], ["replaced", "🧩", "🎉", nil], ["removed", "🧩", nil, admin.id]],
      )
      expect(jobs.pluck("user_id").uniq).to eq([booster.id])
      expect(data).to all(match_node_output_schema(described_class))
    end
  end
end
