import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DiscourseBoostsUserNotificationBoosts = <template>
  <li
    class="user-notifications-bottom-outlet discourse-boosts-user-notification-boosts"
    ...attributes
  >
    <LinkTo @route="userNotifications.boostsReceived">
      {{dIcon "rocket"}}
      <span>{{i18n "discourse_boosts.boosts_title"}}</span>
    </LinkTo>
  </li>
</template>;

export default DiscourseBoostsUserNotificationBoosts;
