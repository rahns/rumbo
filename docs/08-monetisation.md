# 8. Monetisation ideas (not built)

Status: **ideas only, parked for later.** Nothing here is implemented. Rumbo is sideloaded today, so none of it is possible until it's on the App Store. Written down so it isn't lost (November 2026).

## Constraints

- **Apple Developer Program:** $99 a year, App Store distribution. Apple takes 15% under the Small Business Program.
- **No running costs per user:** writing feedback uses each learner's own free Gemini or GroqCloud key, and data stays on the phone. That keeps one-time pricing viable.
- **Subscriptions don't fit:** the author's view is that the app doesn't add enough ongoing value to justify one.
- **App Store review:** needs a privacy policy, and a way for the reviewer to try writing feedback (a demo key, or noting that the basic checker works without one).
- **Names:** don't use "Dreaming Spanish", "Duolingo", "Language Transfer" or "Extra en Español" in the app name or icon. "Works with…" in the description is fine.

## Plan

1. **Free download plus a one-time "Rumbo Plus" unlock, about $5–9** (StoreKit 2: one non-consumable purchase, Restore purchases, feature gating).
   - **Free:** the daily plan, the path, the streak and Pico. They need to be useful on their own.
   - **Plus:** for example AI writing feedback, Lessons, widgets, the Progress charts (level watched, projections), backups, and **no ads**.
2. **A full-screen ad after the first completed activity of the day**, like Duolingo. Free users only; Plus removes it.
   - **When:** at most once a day, only after the first task is logged and its celebration has finished. Never mid-task, during writing, or on the first day.
   - **What it needs:** an ad SDK (e.g. Google AdMob interstitials); App Tracking Transparency (ads are less valuable without tracking consent); a consent prompt in the EU/UK (Google's UMP); the SDK's privacy manifest; and an App Store privacy label that declares advertising data.
   - **Expectation:** small. One interstitial per active user per day earns roughly half a cent to a couple of cents, depending on country and consent. It mostly works as a nudge towards the no-ads unlock.
3. **Tutor affiliate links** from the Lessons feature, e.g. a subtle "Find a tutor" when no lessons are set up. italki and Preply both run affiliate programmes. Check their current terms and Apple's rules on outbound links.
4. **Buy streak freezes:** consumable in-app purchases (e.g. 1 freeze for about $0.99, or a small pack). They'd still be capped at the 2-freeze inventory, so buying can't replace keeping the streak; maybe only offered when the inventory is empty. Needs the freeze count to include purchased freezes alongside earned ones (today it's worked out from history alone), and purchases restored on a new phone.
5. **Optional tip jar:** consumable "Buy Pico a coffee" purchases next to the unlock.

**Skip:** paid-upfront pricing (few people buy unknown apps blind), and ads anywhere else in the app.

## Audience and launch

- **Who:** comprehensible-input learners of Spanish and French using Dreaming and Language Transfer.
- **Where:** r/dreamingspanish, r/French, the Dreaming community and language-learning Discords, with a short demo video of the path, Pico and the daily plan.

## Rough expectations

2,000 downloads a year, with 3–5% unlocking at $6.99, comes to about $350–600 a year after Apple's cut, plus some ad and affiliate income. Word of mouth in the niche could multiply that, but plan for the modest case.
