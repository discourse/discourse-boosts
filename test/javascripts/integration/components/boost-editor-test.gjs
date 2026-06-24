import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BoostEditor from "discourse/plugins/discourse-boosts/discourse/components/boost-editor";

const INPUT = ".discourse-boosts__input";

module("Integration | Component | BoostEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.value = null;
    this.onChange = (value) => (this.value = value);
  });

  async function renderEditor(context) {
    const onChange = context.onChange;

    await render(
      <template>
        <BoostEditor @onChange={{onChange}} @placeholder="Say something" as |editor|>
          <button
            type="button"
            class="test-insert-emoji"
            {{on "click" (fn editor.insertEmoji "grinning")}}
          >insert</button>
        </BoostEditor>
      </template>
    );
  }

  test("inserts an emoji into an empty field without a leading space", async function (assert) {
    await renderEditor(this);

    await click(".test-insert-emoji");

    assert.dom(`${INPUT} img.emoji`).exists("the emoji is inserted");
    assert.strictEqual(
      this.value,
      ":grinning:",
      "the value has no leading whitespace"
    );
  });

  test("separates an emoji from existing text with a single space", async function (assert) {
    await renderEditor(this);

    const input = document.querySelector(INPUT);
    input.textContent = "hi";
    await triggerEvent(input, "input");

    await click(".test-insert-emoji");

    assert.strictEqual(
      this.value,
      "hi :grinning:",
      "a single space separates the text from the emoji"
    );
  });

  test("clears the browser filler node once the field is emptied", async function (assert) {
    await renderEditor(this);

    const input = document.querySelector(INPUT);
    input.textContent = "hi";
    await triggerEvent(input, "input");

    // Browsers leave a filler <br> behind after all text is deleted.
    input.innerHTML = "<br>";
    await triggerEvent(input, "input");

    assert.strictEqual(
      input.childNodes.length,
      0,
      "the field is empty so the :empty placeholder shows again"
    );
    assert.strictEqual(this.value, "", "the reported value is empty");
  });

  test("does not push an emoji onto a new line after the field was emptied", async function (assert) {
    await renderEditor(this);

    const input = document.querySelector(INPUT);

    // Reproduces the bug: type, delete everything (browser leaves a filler
    // <br>), then pick an emoji.
    input.innerHTML = "<br>";

    await click(".test-insert-emoji");

    assert.dom(`${INPUT} br`).doesNotExist("the filler newline is removed");
    assert.dom(`${INPUT} img.emoji`).exists("the emoji is inserted");
    assert.strictEqual(
      input.firstChild?.nodeName,
      "IMG",
      "the emoji is the first node, not preceded by a newline"
    );
    assert.strictEqual(
      this.value,
      ":grinning:",
      "the value has no leading newline or space"
    );
  });
});
