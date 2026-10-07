import { modifier } from "ember-modifier";
import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";

// Focusing the input opens the on-screen keyboard, which scrolls the page to keep the input visible
// that scroll shouldn't dismiss the menu the user is typing into.
export default modifier((element, [trigger, onClose]) => {
  if (!trigger) {
    return;
  }

  const scrollParent = getScrollParent(trigger) ?? window;
  const handler = () => {
    if (!element.contains(document.activeElement)) {
      onClose();
    }
  };

  scrollParent.addEventListener("scroll", handler, { passive: true });

  return () => {
    scrollParent.removeEventListener("scroll", handler);
  };
});
