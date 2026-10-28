# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Boost::V1 do
  fab!(:post)
  fab!(:actor, :user)

  before { SiteSetting.discourse_boosts_enabled = true }

  describe ".upgrade" do
    let(:boost_parameters) { { "post_id" => "={{ $json.post.id }}", "actor_username" => "system" } }
    let(:notes) { ["discourse_boosts.discourse_workflows.node_upgrades.boost_output"] }

    it "moves adding to Boost post, keeping the text and if_exists" do
      parameters =
        boost_parameters.merge("operation" => "add", "text" => "🚀", "if_exists" => "replace")

      expect(described_class.upgrade(parameters)).to eq(
        type: "action:boost_post",
        parameters: parameters.except("operation"),
        notes:,
      )
    end

    it "moves removing to Remove boost" do
      parameters = boost_parameters.merge("operation" => "remove", "if_exists" => "keep")

      expect(described_class.upgrade(parameters)).to eq(
        type: "action:remove_boost",
        parameters: boost_parameters,
        notes:,
      )
    end

    it "leaves a node whose operation is an expression to be replaced by hand" do
      expect(described_class.upgrade("operation" => "={{ $json.operation }}")).to be_nil
    end
  end

  describe "#execute" do
    let(:configuration) do
      {
        "operation" => operation,
        "post_id" => post.id.to_s,
        "text" => "🧩 certified",
        "if_exists" => if_exists,
        "actor_username" => actor.username,
      }
    end
    let(:if_exists) { "keep" }

    def current_boost
      DiscourseBoosts::Boost.find_by(post:, user: actor)
    end

    context "with add operation" do
      let(:operation) { "add" }

      it "boosts the post as the actor" do
        result = execute_node(configuration:)

        expect(result).to eq(
          "post_id" => post.id,
          "username" => actor.username,
          "boost_id" => current_boost.id,
          "text" => "🧩 certified",
          "previous_text" => nil,
          "changed" => true,
        )
        expect(result).to match_node_output_schema(described_class)
      end

      it "keeps an existing boost by default" do
        Fabricate(:boost, post:, user: actor, raw: "🎉")

        expect(execute_node(configuration:)).to include(
          "text" => "🎉",
          "previous_text" => "🎉",
          "changed" => false,
        )
      end

      context "when replacing existing boosts" do
        let(:if_exists) { "replace" }

        it "replaces the text of an existing boost" do
          boost = Fabricate(:boost, post:, user: actor, raw: "🎉")

          expect(execute_node(configuration:)).to include(
            "boost_id" => boost.id,
            "text" => "🧩 certified",
            "previous_text" => "🎉",
            "changed" => true,
          )
        end

        it "keeps the existing boost when the new text is invalid" do
          Fabricate(:boost, post:, user: actor, raw: "🎉")
          configuration["text"] = "this note is way too long for a boost"

          expect { execute_node(configuration:) }.to raise_error(
            DiscourseWorkflows::NodeError,
            /#{I18n.t("discourse_boosts.boost_too_long", count: DiscourseBoosts::Boost::MAX_VISIBLE_LENGTH)}/,
          )
          expect(current_boost.raw).to eq("🎉")
        end
      end

      it "fails without a text" do
        configuration["text"] = " "

        expect { execute_node(configuration:) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /#{I18n.t("discourse_boosts.boost_blank")}/,
        )
      end

      it "fails when the actor cannot boost the post" do
        configuration["actor_username"] = post.user.username

        expect { execute_node(configuration:) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /#{post.user.username}/,
        )
      end
    end

    context "with remove operation" do
      let(:operation) { "remove" }

      it "removes the actor's boost" do
        Fabricate(:boost, post:, user: actor, raw: "🎉")

        expect(execute_node(configuration:)).to include(
          "boost_id" => nil,
          "text" => nil,
          "previous_text" => "🎉",
          "changed" => true,
        )
        expect(current_boost).to be_nil
      end

      it "does nothing when the actor has not boosted the post" do
        expect(execute_node(configuration:)).to include("changed" => false)
      end
    end
  end
end
