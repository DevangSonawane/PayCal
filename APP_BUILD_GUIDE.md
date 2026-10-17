# {{APP_NAME}} — Flutter Build Guide (UI/UX first)

> **Audience:** the AI coding agent (opencode) building this app, and the human supervising it.
> **How to use:** save this file in the project root as `AGENTS.md` (opencode reads project-root instructions from it; if your setup does not, tell the agent: "Read BUILD_GUIDE.md before every task"). Keep `PRD.md` (v1.1) next to it. Where the two disagree, **the PRD wins on behaviour, this guide wins on look and feel**.
> **Placeholders:** replace `{{APP_NAME}}` everywhere. Never hardcode the name in widgets; read it from one constant and from localization strings.

---

## 0. Read this first (rules for the agent)

1. **Build UI/UX before features.** A screen is not done until it matches sections 3–9 of this guide: tokens, spacing, type, states, motion, accessibility.
2. **No hardcoded design values in widgets.** No `Color(0x…)`, raw font sizes, raw padding numbers, or raw durations outside `lib/core/theme/`. Use tokens. Add a CI check (grep) that fails on `Color(0x` and `fontSize:` outside the theme folder.
3. **No gradients, no neon, no saturated colours, no heavy shadows.** White background, quiet colours (section 3). If you are unsure whether a colour is allowed, it is not.
4. **One screen = one clear job.** One primary action per screen, pinned at the bottom, reachable by thumb.
5. **Every screen has all of its states:** loading, empty, error, content, and (where relevant) offline. Never ship only the happy path.
6. **Ask before adding a package** that is not in section 12. Prefer fewer dependencies.
7. **Money is never a `double`.** Store integer minor units (paise, kopeks) plus a currency code. See PRD section 6.3.
8. **All user-facing text goes through localization** (`intl` / ARB files), even though v1 ships in English.
9. After each task: run `flutter analyze`, run tests, and show what changed. Do not claim a screen "matches the design" without running it on an Android emulator at 360×800 and 412×915 and at text scale 1.0 and 1.3.
10. If an instruction here is ambiguous or conflicts with the PRD, stop and ask one precise question instead of guessing.

---

## 1. Product feel in one paragraph

A calm, minimal, white app that makes shared money feel easy rather than awkward. It is used mostly by Gen Z on Android. It should feel like Cash App / Linear / Monzo in restraint: lots of whitespace, big confident numbers, one strong black action per screen, tiny status colours that only appear when they carry meaning, and floating frosted-glass layers (nav bar, bottom sheets, dialogs) that give depth without decoration. Friendly, short, lower-key copy. Never preachy, never corporate.

**Keywords:** minimal · airy · confident · quiet colour · glass only on floating layers · thumb-friendly · fast.

### 1.1 Reference research (Mobbin and others)

The agent cannot log in to Mobbin. **The human** should collect references and drop screenshots in `design/references/` (the agent should read any images placed there before designing a screen). Suggested Mobbin searches and what to look for:

| Search on Mobbin | Look for |
|---|---|
| Onboarding flows (fintech, habit, social) | One question per screen, thin progress bar, sticky bottom button, selectable tiles |
| Bottom sheet / modal | Drag handle, rounded top corners, scrim, pinned action, keyboard behaviour |
| Date picker / birthday | Wheel pickers, inline vs sheet, validation copy |
| Empty states | One line of copy + one action, no illustrations overload |
| Tab bar / floating nav | Floating pill nav, centre add button, glass blur |
| Split bill / expense apps (Splitwise, Cash App, Revolut, Monzo, Venmo) | Balance hierarchy, "you owe / you are owed" colour use, settle-up flow |
| Settings / profile | Grouped lists, rows with trailing values |

Capture patterns, not pixels. Do not copy another app's exact layout, brand, or illustrations.

---

## 2. Information architecture

```
Splash
└─ Welcome ── Get started ──► Onboarding (Gender → Birthday → Role → Role details) ──► Create account ──► Verify email ──► Notifications priming ──► First batch (create or join) ──► Invite members ──► Home
          └─ Sign in (returning users) ──► Home
Main shell (floating glass bottom nav)
├─ Home            (PRD §12: net position per currency, batches, recent activity, upcoming, pending)
├─ Batches         (list; open a batch)
├─ [ + ] Quick Add (opens bottom sheet; PRD §4.1)
├─ Activity        (PRD §13 feed across batches)
└─ Profile         (account, notifications, privacy, delete account)
Batch detail
├─ Expenses | Balances | Members | Reports   (segmented control)
├─ Expense detail (+ flag dispute, edit, history)
├─ Settle up sheet (full amount only; two methods)
└─ Batch settings (currency, categories, recurring, admin tools)
```

Navigation rules: bottom nav only on the 4 top-level tabs. Everything deeper uses push with a back button. Modals (add expense, pickers, confirmations) are bottom sheets, not centre dialogs.

---

## 3. Design tokens

All tokens live in `lib/core/theme/`. Suggested files: `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`, `app_radii.dart`, `app_motion.dart`, `app_theme.dart`.

### 3.1 Colour (light only for v1; structure tokens so dark mode can be added later)

Background is white. Colour appears only for meaning (status, money direction) and for tiny identity tints (avatars, categories).

| Token | Hex | Use |
|---|---|---|
| `bg` | `#FFFFFF` | Every screen background |
| `surface` | `#F7F7F5` | Cards, input fills, selected tile background |
| `surfaceRaised` | `#FFFFFF` | Sheets/cards on `surface` |
| `border` | `#ECECE8` | 1 px hairlines, tile outlines |
| `borderStrong` | `#D9D9D4` | Focused/hover outlines, drag handle |
| `textPrimary` | `#111111` | Headings, amounts, primary button fill |
| `textSecondary` | `#5F5F5B` | Body support text, captions |
| `textTertiary` | `#767672` | Placeholders, hints (the lightest allowed for readable text) |
| `textDisabled` | `#B8B8B3` | Disabled only (not for readable content) |
| `onPrimary` | `#FFFFFF` | Text on the black button |
| `owed` (positive) | text `#2F6F52`, tint `#E9F2EC` | "You are owed", confirmed |
| `owe` (negative) | text `#A4472F`, tint `#F7EBE6` | "You owe", disputed, destructive |
| `pending` | text `#845A10`, tint `#FAF2E1` | Pending settlement, unpaid reminder |
| `info` | text `#385878`, tint `#E9EFF5` | Neutral information, links |
| `scrim` | `#000000` at 24% | Behind sheets |

Identity tints (avatars and categories; text colour + background pair, assigned by hashing an id so they stay stable):

| Name | Background | Foreground |
|---|---|---|
| sage | `#E9F0EA` | `#2F5D45` |
| sand | `#F4EEE2` | `#7A5C1E` |
| clay | `#F6E9E4` | `#8F4430` |
| sky | `#E7EEF5` | `#355A7D` |
| lilac | `#EEEAF4` | `#5B4A7D` |
| stone | `#EEEEEC` | `#4A4A47` |

Rules:
- The **primary button is black** (`textPrimary`) with white text. Colour is never used to make a button "pop".
- Status is never communicated by colour alone: always pair with an icon and a word ("Pending", "Confirmed").
- Every text/background pair must pass WCAG AA (4.5:1 body, 3:1 large). Add a unit test that checks all token pairs.
- Forbidden: gradients (including shimmer and glass sheen), neon, saturated primaries, coloured shadows, colourful illustrations.

### 3.2 Typography

Single family: **Inter** (bundle the font files in `assets/fonts/`; do not fetch at runtime). Numbers use tabular figures (`FontFeature.tabularFigures()`) so amounts align.

Only four weights are allowed: **400 Regular, 500 Medium, 600 SemiBold, 700 Bold.** Minimum size 12 sp. Support text scale up to 1.3 without clipping; layouts must wrap or scroll rather than truncate important content.

| Style | Size / line height | Weight | Letter spacing | Use |
|---|---|---|---|---|
| `displayAmount` | 44 / 52 | 700 | -1.0 | Hero balance on Home / Batch |
| `display` | 32 / 40 | 700 | -0.6 | Welcome title |
| `headline` | 28 / 34 | 700 | -0.4 | Onboarding question, screen titles |
| `title` | 20 / 26 | 600 | -0.2 | Section titles, sheet titles |
| `titleSmall` | 17 / 24 | 600 | 0 | List item titles, card titles |
| `bodyLarge` | 16 / 24 | 400 | 0 | Primary reading text, input text |
| `body` | 14 / 20 | 400 | 0 | Secondary text, descriptions |
| `label` | 14 / 20 | 500 | 0.1 | Buttons, chips, tabs |
| `caption` | 12 / 16 | 500 | 0.2 | Timestamps, helper text, status chips |
| `amount` | 17 / 24 | 600 | 0 | Amounts in lists (tabular) |

Hierarchy rules: one `headline` per screen; at most two weights visible in any one card; never use bold for body paragraphs; never use all-caps except `caption` labels in tiny section headers (optional).

### 3.3 Spacing, radii, sizing

4 pt grid. Spacing tokens: `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 20`, `xxl 24`, `xxxl 32`, `huge 48`.

- Screen horizontal padding: **20**.
- Section gap: **24–32**. Related items gap: **8–12**.
- Radii: input/button **16**, card **20**, sheet top **28**, chip/pill **999**, avatar **999**, tile **16**.
- Minimum touch target **48 × 48**. Primary button height **56**, secondary **48**, chip **36** (with 48 hit area).
- Bottom safe area is always respected; the pinned action sits 16 above the safe area (and above the keyboard when open).

### 3.4 Elevation and borders

No elevation system. Depth comes from 1 px `border`, surface tint, and glass. The only shadow allowed is on floating glass layers: `0 8 24 rgba(0,0,0,0.06)`. No inner glows.

### 3.5 Iconography

One icon set, outline style, 1.5 px stroke, 24 px (20 px inside chips). Use Phosphor (Regular weight) via `phosphor_flutter`, or Lucide if preferred; do not mix sets. Icons never carry colour except status icons using the status text colour. No emoji in UI chrome. Emoji are acceptable only inside user-generated content.

### 3.6 Motion

| Token | Value | Use |
|---|---|---|
| `fast` | 150 ms | Taps, toggles, chips |
| `base` | 250 ms | Page transitions, tile selection, content swaps |
| `slow` | 350 ms | Sheets, hero/shared elements |
| Curves | `easeOutCubic` in, `easeInCubic` out; sheets use a gentle spring-like `easeOutQuart` | |

- Page transitions: horizontal shared-axis slide (16–24 px offset) with fade for onboarding steps; fade-through between bottom-nav tabs.
- Button press: scale to 0.98 over `fast` + light haptic (`HapticFeedback.selectionClick`).
- Success moments (expense saved, settled): subtle check animation ≤ 400 ms and a medium haptic. No confetti.
- Loading: skeleton blocks using a **gentle opacity pulse** (not a gradient shimmer).
- Respect "remove animations": when `MediaQuery.disableAnimationsOf(context)` is true, use instant or fade-only transitions.
- Android 14+ predictive back must work: use `PopScope` correctly on onboarding and sheets.

---

## 4. Liquid-glass spec (without gradients)

"Liquid glass" here means **frosted, translucent, floating layers**. It is emulated in Flutter (there is no native widget), using blur plus a translucent white fill and a hairline edge.

**Where glass is allowed:** floating bottom nav, bottom sheets, confirmation sheets, toasts/snackbars, the top app bar only while content scrolls beneath it.
**Where glass is NOT allowed:** page backgrounds, list cards, inputs, buttons. Content stays solid and flat.

Recipe (no gradient anywhere):

- Backdrop blur: sigma **24** (nav bar, toasts), **28** (sheets).
- Fill: white at **72%** (nav/toasts), **86%** (sheets, for legibility of forms).
- Edge: **0.5 px** border, black at 8% (works on white) plus an optional second 0.5 px inner white 60% line for the "lit edge" effect (flat colour, no sheen).
- Shadow: `0 8 24 rgba(0,0,0,0.06)` only.
- Sheets sit on `scrim` (black 24%) so the blur has something to refract; without a scrim a white sheet over a white page reads as a plain card, which is fine.

Reference implementation (adapt names to project conventions):

```dart
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 24,
    this.fillOpacity = 0.72,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double fillOpacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final useSolid = MediaQuery.highContrastOf(context) || !GlassConfig.enabled;

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useSolid
            ? AppColors.surfaceRaised
            : Colors.white.withValues(alpha: fillOpacity),
        borderRadius: shape,
        border: Border.all(color: AppColors.glassEdge, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );

    if (useSolid) return box;
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      ),
    );
  }
}
```

Performance rules (Android-first):
- At most **two** blur layers visible at once (nav bar + one sheet).
- Wrap scrolling content that sits under glass in `RepaintBoundary`.
- `GlassConfig.enabled` must be switchable (remote flag or a low-end-device heuristic). The fallback is solid `surfaceRaised` with the same border, and it must look good by itself.
- Test on a low-end Android device or emulator profile and check the frame times in DevTools; if a sheet drops frames, reduce sigma before removing glass.

---

## 5. Component library

Build these in `lib/core/widgets/` before building screens. Each gets a widget test and a golden test (light, text scale 1.0 and 1.3).

| Component | Spec |
|---|---|
| `PrimaryButton` | Full width, 56 high, radius 16, fill `textPrimary`, text `label` white; disabled: fill `border`, text `textDisabled`; loading: replace label with 20 px spinner (white); press scale 0.98 |
| `SecondaryButton` | 48–56 high, fill `surface`, text `textPrimary`, no border |
| `QuietTextButton` | `label` in `textPrimary`, underline none, 48 hit height; used for "Sign in", "Skip" |
| `OptionTile` | Full width, min 60 high, radius 16, 1 px `border`, leading icon (optional), `titleSmall` + `body` support text; selected: 1.5 px `textPrimary` border, `surface` fill, trailing check icon; animates over `base` |
| `AppTextField` | Label above (`caption`/`label`), 56 high, fill `surface`, radius 16, no border until focus then 1.5 px `textPrimary`; error: `owe` text below + `owe` border; always visible label (not only placeholder) |
| `AmountField` | Large `displayAmount` style, currency symbol prefix, numeric keyboard, tabular figures; shows live formatted value |
| `OnboardingProgress` | Thin 4 px segmented bar at top (`border` track, `textPrimary` fill), animates over `base`; sits under the safe area, back chevron on the left |
| `GlassBottomNav` | Floating pill, 64 high, 16 margin from edges and safe area; 4 destinations + centre add button (black circle 56, white plus icon); labels shown only on the active tab or icon-only with accessible labels |
| `AppBottomSheet` | `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`, transparent background; content in `Glass(radius 28 top)`, drag handle 36×4 `borderStrong`, title `title`, pinned footer action, keyboard-aware (`viewInsets`), max height 90% of screen |
| `ConfirmSheet` | Title, one-line explanation, primary action, cancel; destructive variant: primary action text in `owe`, fill `owe` tint (never solid red) |
| `Avatar` | Initials on an identity tint, sizes 24/32/40/56; stacked avatars overlap by 8 with a 2 px `bg` ring |
| `StatusChip` | `caption`, pill, tint background + status text colour + 16 px icon; variants: pending, confirmed, self-managed, disputed, outstanding, paid |
| `MoneyText` | Formats minor units with currency; colours: `textPrimary` default, `owed`/`owe` when direction matters; always tabular |
| `ListRow` | 64–72 high, leading avatar/icon, title + support text, trailing amount/chevron; hairline separator inset 76 px |
| `EmptyState` | Small line icon (48 px, `textTertiary`), `titleSmall` heading, `body` one-liner, one `SecondaryButton`; no illustrations |
| `Skeleton` | Rounded blocks in `surface` with opacity pulse 0.6–1.0 over 1200 ms |
| `AppToast` | Glass pill at top (below safe area), 3 s, icon + one line; max one at a time |
| `SegmentedControl` | Pill track `surface`, selected thumb white with 1 px `border`, `label` text |

Copy conventions: sentence case, no exclamation marks except celebratory success, no jargon ("settle up", not "reconcile").

---

## 6. Onboarding flow (the most important part)

**Goal:** a new user reaches their first batch in under 90 seconds, feels it was effortless, and the app knows enough to personalise their first batch. Principles: one question per screen, big tappable answers, always a way back, always a way to skip anything that is not required, never ask for what Google can provide.

### 6.1 Flow overview

```
S0 Splash → S1 Welcome
  ├─ [Get started] → S2 Gender → S3 Birthday → S4 Role → S5 Role details (2 mini-steps) → S6 Create account → S7 Verify email → S8 Notifications priming → S9 First batch → S10 Invite members → Home
  └─ [Sign in] (below the button) → Sign-in screen → Home (or resume onboarding if the profile is incomplete)
```

Persist the in-progress answers locally (`OnboardingDraft`) so a killed app resumes at the same step. Create the account **after** the questions, because answering feels like progress and the account step feels like the finish line. Attach the saved answers to the new profile on account creation.

> **Assumption to confirm:** the message that defined this flow ended at "…then your role and then accordingly". I interpreted "accordingly" as role-based personalisation of the first batch (S5, S9). If you meant something else, change S5/S9 only; the rest of the flow stands.

### 6.2 Shared onboarding layout (S2–S5)

- Top: back chevron (left) and `OnboardingProgress` (fills across the whole bar: 5 steps — gender, birthday, role, details 1, details 2).
- Question: `headline`, left aligned, 24 below the top bar. Support text: `body` in `textSecondary`, 8 below.
- Answer area: 24 below, scrollable if needed.
- Bottom: `PrimaryButton` "Continue", pinned, disabled until valid. Optional `QuietTextButton` "Skip" centered 8 below where skipping is allowed.
- Keyboard-open: button rides above the keyboard.
- Step transition: shared-axis horizontal, `base` duration. Back reverses it.
- Haptic: `selectionClick` on option select.

### 6.3 Screens

**S0 Splash.** White background, wordmark centred, no animation longer than 600 ms. Handles auth check and routing (new → Welcome, signed-in → Home, mid-onboarding → resume).

**S1 Welcome** (as requested: title, Get started at the bottom, and below it the sign-in link)
- Top ~55%: a calm hero area. Use a flat, minimal composition built from the app's own UI (e.g. three stacked rounded `surface` cards showing a mock expense row, a balance chip, and an avatar stack) on white. No gradients, no stock illustration.
- Title (`display`): "Welcome to {{APP_NAME}}"
- Subtitle (`bodyLarge`, `textSecondary`, max 2 lines): "Split bills with the people you live and travel with. No awkward math."
- Bottom stack, 20 side padding, 16 above safe area:
  1. `PrimaryButton` **"Get started"**
  2. 16 gap, then centered `body` text: "Already have an account? **Sign in**" ("Sign in" is a `QuietTextButton`, `label` weight 600)
  3. 16 gap, `caption` `textTertiary`: "By continuing you agree to our Terms and Privacy Policy" (links open in a sheet/web view)
- Entrance: content fades and rises 12 px, staggered 60 ms, once.

**S2 Gender**
- Question: "How do you identify?" Support: "Helps us personalise your experience. It's never shown to others."
- `OptionTile`s (single select): Woman, Man, Non-binary, Prefer not to say.
- Optional: skip allowed ("Skip for now" selects `preferNotToSay`).
- Do not use gendered icons or colours. Use a neutral glyph or none.

**S3 Birthday**
- Question: "When's your birthday?" Support: "We use this to confirm your age. It's never shown to others."
- Input: a tappable field that opens an `AppBottomSheet` with a three-column wheel picker (day / month / year) and a "Done" button; or an inline wheel below the field on large screens. Default wheel position: 1 Jan, 22 years ago. Max date today.
- Validation: show the age-gate message if under the minimum age (see below); never allow a future date.
- Required (cannot skip), because of the age gate.
- Minimum age: define `kMinimumAge` in one config file, **default 18, pending legal confirmation.** Indian data-protection rules treat under-18s as children and require parental consent mechanisms, so launching to teenagers needs a legal decision. Under-age copy: "You need to be at least {age} to use {{APP_NAME}}." with a single "Okay" action that returns to Welcome and clears the draft.
- Privacy: store the date of birth server-side only; never expose it to other batch members (PRD §15). Consider storing only the birth year after verification if the product does not need the full date.

**S4 Role**
- Question: "What brings you here?" Support: "Pick the one that fits best. You can add more groups later."
- `OptionTile`s with a leading line icon, title and one-line support text (single select):

| Role | Support text | Seeds (see S5/S9) |
|---|---|---|
| Student | Hostel, PG, college trips | Categories: rent, food, travel, subscriptions, other; household size default 3 |
| Sharing a flat | Roommates and monthly bills | Categories: rent, groceries, electricity, internet, cleaning, other; offer a monthly rent recurring expense; default 3 |
| Couple | Everyday life together | Categories: groceries, dining, rent, travel, subscriptions, other; default 2 |
| Family | Home and household costs | Categories: groceries, utilities, school, health, travel, other; default 4 |
| Trip planner | Holidays with friends | Categories: stay, transport, food, activities, other; one-off batch (no recurring); default 4 |
| Team or office | Lunches, gifts, events | Categories: food, gifts, events, supplies, other; default 5 |

- There is no "Other" option and **no default selection**. Continue stays disabled until the user picks one.

**S5 Role details (2 mini-steps, same layout)**
- 5a: "What will you split?" Multi-select chips (4–6 per role, from the role's categories above; at least one required). These become the first batch's active categories (PRD §8).
- 5b: "How many people, including you?" A stepper (− / number / +, range 2–20) with `displayAmount`-sized number. Default from the role table. Used only to suggest the invite step and equal-split defaults, not to restrict anything.

**S6 Create account**
- Title: "Create your account." Support: "One last step."
- Top: **"Continue with Google"** (`SecondaryButton` with the Google mark, following Google branding rules) then a divider with "or".
- Email path fields: Full name, Email, Password (with show/hide, strength hint as text: "At least 8 characters"). One `PrimaryButton` "Create account".
- If Google is used, skip the name field if Google provides it, but let the user edit the display name on the next screen if it is empty.
- Error handling: inline field errors, plain English ("That email is already in use. Try signing in."), never a raw exception.
- On success: write the profile (`gender`, `birthDate`, `role`, `splitTypes`, `householdSize`), clear the draft.
- Legal line repeated as `caption`.

**S7 Verify email** (PRD §2.1: verification before creating or joining a batch)
- Skipped for Google sign-ins (already verified).
- Title "Check your inbox", support text showing the address, a primary "Open email app" button, "Resend" with a 30 s cooldown shown as a countdown, and "Use a different email". Poll or deep-link to detect verification; on success, a short check animation then continue.

**S8 Notifications priming**
- Before the system prompt, show an `AppBottomSheet`: title "Never miss a split", three short lines (new expenses, payment requests, reminders), buttons "Turn on notifications" (triggers the Android 13+ system permission) and "Not now".
- If denied, the app still works; show a quiet banner in Profile with a "Turn on" action later. Never re-prompt repeatedly.

**S9 First batch** (PRD §3)
- Segmented choice at the top: **Create a batch** | **Join with a link**.
- Create: batch name (pre-filled from role: "Our flat", "Goa trip", "Home", "Office lunch"…), **currency** (sheet with search; default from device locale, e.g. INR; helper text: "Everyone in this batch uses this currency. You can change it later; amounts won't be converted." per PRD §3.2), and the pre-selected categories from S5a shown as removable chips. If the role is "Sharing a flat", show an optional card "Add monthly rent" that opens the recurring sheet (PRD §5).
- Join: paste an invite link or enter a code; on success show "Request sent. The admin will approve you." (PRD §3.4: admin approval is required).
- `PrimaryButton` "Create batch" / "Request to join".

**S10 Invite members**
- Title "Add your people". Primary: "Share invite link" (opens the system share sheet via `share_plus`) with a `SecondaryButton` "Invite by email or username". Show the invite link in a copyable pill. Explain in one line: "New members need your approval before they can join."
- `QuietTextButton` "Skip for now".

**Finish.** A quiet full-screen "You're all set" for ≤ 1.2 s (check animation, no confetti), then Home with a tailored empty state (see 7.1) and at most three coach-mark tooltips (add expense, balances, settle up) that are dismissible and never shown again.

### 6.4 Returning users: Sign in
- Reached from the Welcome link. Title "Welcome back". Google button, then email + password, "Forgot password?" (opens a `ConfirmSheet`-style sheet that sends a reset link, PRD §2.1), and the primary "Sign in".
- If the signed-in account has no completed profile, resume onboarding at the first missing step.

### 6.5 Onboarding copy deck (put in ARB; edit freely, keep the voice)

| Key | English |
|---|---|
| welcomeTitle | Welcome to {{APP_NAME}} |
| welcomeSubtitle | Split bills with the people you live and travel with. No awkward math. |
| getStarted | Get started |
| haveAccount | Already have an account? |
| signIn | Sign in |
| genderQuestion | How do you identify? |
| genderHelper | Helps us personalise your experience. It's never shown to others. |
| birthdayQuestion | When's your birthday? |
| birthdayHelper | We use this to confirm your age. It's never shown to others. |
| roleQuestion | What brings you here? |
| roleHelper | Pick the one that fits best. You can add more groups later. |
| splitQuestion | What will you split? |
| peopleQuestion | How many people, including you? |
| createAccountTitle | Create your account |
| verifyTitle | Check your inbox |
| notifTitle | Never miss a split |
| firstBatchTitle | Set up your first batch |
| inviteTitle | Add your people |
| allSet | You're all set |

---

## 7. Core screens (specs for the MVP shell)

### 7.1 Home (PRD §12)
- Top: greeting `titleSmall` "Hi, {firstName}" and the avatar button (opens Profile). No emoji.
- **Hero balance:** one card per currency the user has activity in. `displayAmount` for the net amount, `body` label "You're owed" (`owed`) or "You owe" (`owe`) or "All settled" (`textSecondary`). Never sum across currencies (PRD §3.2). Beneath, two `StatusChip`-like stat pills: "Owed to you ₹X" and "You owe ₹X".
- **Needs attention:** pending settlements, unpaid expenses (rows with chips). Hidden when empty.
- **Your batches:** horizontally stacked cards or a list: name, avatar stack, your net in this batch, tap to open.
- **Upcoming:** next recurring expenses with date and amount.
- **Recent activity:** last 5 events with "See all".
- **Empty state (new user):** a single card: "Add your first expense" + "Add expense" button; if the batch has no members yet, "Invite your people" instead. No illustration.
- Pull to refresh; skeletons during first load.

### 7.2 Quick Add sheet (PRD §4.1) — the app's signature interaction
Opened by the centre "+" button. A tall `AppBottomSheet` (about 85% height), glass 86% fill.
1. `AmountField` first, auto-focused, with a currency symbol of the active batch.
2. Description field ("What was it for?").
3. A row of tappable chips: **Batch** (if more than one), **Paid by You**, **Split equally · 4 people**, **Today**, **Category**. Each chip opens a small selection sheet.
4. Live preview line under the chips: "₹250 each" (equal) or per-person shares for custom/percentage (PRD §4.2: show each share before saving).
5. "More details" expands the Full Expense Form fields inline (notes, recurring, custom split, date).
6. Pinned `PrimaryButton` "Add expense". On save: sheet closes, toast "Expense added", balances update.
- Validation messages explain how to fix ("Percentages add up to 90%. Add 10% more.").
- Remember the last batch, payer and split method as defaults.

### 7.3 Batch detail
- Header: batch name `headline`, currency chip, avatar stack, overflow menu (settings).
- Hero: your net in this batch, plus "Settle up" `PrimaryButton` when a balance exists.
- `SegmentedControl`: **Expenses** | **Balances** | **Members** | **Reports**.
- Expenses: grouped by date headers (`caption`), `ListRow`s with category tint icon, description, "Paid by Asha", amount on the right, `StatusChip` if unpaid/disputed. Filters (date, category, payer, participant, status; PRD §9.2) in a filter sheet opened from a funnel icon, with an active-filter count badge.
- Balances: each member row with paid, share, net (PRD §6.2).
- Members: list with roles (Admin badge), invite button, pending requests at the top for admins.
- Reports: monthly/custom range switcher and category totals as simple horizontal bars (flat `surface` tracks, tint fills, no gradients).

### 7.4 Expense detail
- Amount `displayAmount`, description `headline`, a flat info list (date, payer, participants with shares, split method, category, notes).
- Status chip, "Flag a problem" `SecondaryButton` (opens sheet with reason chips and a text field, PRD §10), and for authorised users "Edit" / "Delete" (delete uses `ConfirmSheet`).
- "History" section: audit entries (PRD §13), collapsed by default.

### 7.5 Settle up sheet (PRD §7)
- Shows the person, the **full amount** (not editable, per the "full settlement only" decision), and two options as `OptionTile`s:
  - **Ask {name} to confirm** — "Pending until they confirm."
  - **Mark as settled myself** — "We can't verify the transfer. It will be labelled Self-managed."
- `PrimaryButton` "Record settlement". Pending items show an amber `StatusChip`; confirmed show green; self-managed show a stone chip with an info icon that opens a one-line explanation.
- Edge case (balance changed after recording): show a `pending` banner on the settlement with "Balance changed. Review". (Behaviour pending PRD open decision.)

### 7.6 Profile and settings
- Grouped list rows: Account, Notifications, Batches (leave, admin recovery), Privacy, Help, Delete account.
- Delete account: `ConfirmSheet` that explains anonymisation (PRD §14), lists outstanding balances as a warning, and requires typing the word DELETE (or re-auth).

---

## 8. Accessibility checklist

- Touch targets ≥ 48 dp; spacing ≥ 8 dp between targets.
- `Semantics` labels on every icon-only control (nav items, add button, back, close).
- Text scales to 130% without overlap; test with large font setting.
- Colour contrast AA for all text; status never colour-only.
- TalkBack: logical focus order; sheets announce their title when opened; toasts use live regions.
- Reduce motion respected (section 3.6).
- Forms: label always visible, errors announced, correct keyboard types and `autofillHints` (name, email, new-password).

## 9. Empty, loading, error and offline states

| State | Pattern |
|---|---|
| Loading first time | Skeletons matching final layout; no spinners except inside buttons |
| Empty | `EmptyState` (icon, one line, one action) |
| Error (recoverable) | Inline message + "Try again" `SecondaryButton`; keep previously loaded data visible |
| Offline | Thin `info` banner under the app bar: "You're offline. Changes will sync when you're back." Reading cached data allowed; writing queued or disabled per feature |
| Permission denied | Explain value in one line and offer "Open settings" |

---

## 10. Architecture and project structure

Flutter, Dart null-safe, Android-first (min SDK per Flutter default; edge-to-edge enabled). Feature-first folders:

```
lib/
  main.dart
  app/                  # app widget, router, bootstrapping
  core/
    theme/              # tokens (colors, typography, spacing, radii, motion), ThemeData
    widgets/            # component library (section 5)
    utils/              # money, dates, validators
    l10n/               # ARB files
  data/                 # repositories (interfaces + implementations), DTOs
  domain/               # entities, calculation engine (balances, splits, rounding)
  features/
    onboarding/         # welcome, gender, birthday, role, details, controllers, draft storage
    auth/               # sign-in, create account, verify email, password reset
    batches/
    expenses/
    settlements/
    recurring/
    reports/
    activity/
    profile/
test/                   # unit + widget + golden tests mirror lib/
```

- State management: **Riverpod** (`flutter_riverpod`). Navigation: **go_router** with an auth/onboarding redirect guard.
- Repositories sit behind interfaces. **Backend is not yet chosen** (PRD open). Build against an in-memory/mock implementation first so the UI is complete and testable, then swap in the real backend (Firebase or Supabase are the usual Android-first choices). The backend must enforce permissions (PRD §15); client checks are only for UX.
- The balance/split/rounding engine is a pure Dart module in `domain/`, fully unit-tested (equal, custom, percentage, rounding remainder, edits, deletions, settlements). All screens read balances only from this engine so figures stay consistent (PRD §6.3, §9.4).
- Money: `Money(int minorUnits, String currency)`; parsing and formatting through `intl`; currency precision from the currency code.
- Audit/activity: every domain mutation emits an event (PRD §13) from one place.

## 11. Testing and quality gates

- `flutter analyze` clean; `dart format` enforced.
- Unit tests: calculation engine, validators (percentages sum to 100%, custom amounts equal total), age gate, onboarding draft persistence.
- Widget tests: each component and each onboarding screen (selection enables Continue, back restores answers).
- Golden tests: light theme, 360 px wide, text scale 1.0 and 1.3, for the component library and the onboarding screens.
- Integration test: full onboarding happy path with a mock auth repo.
- Contrast test over token pairs.
- Manual device checklist before each milestone: low-end Android, gesture nav and 3-button nav, keyboard open on every form, TalkBack on onboarding.

## 12. Suggested packages (ask before adding others)

`flutter_riverpod`, `go_router`, `intl`, `shared_preferences` (onboarding draft), `phosphor_flutter` (icons), `flutter_animate` (subtle motion), `share_plus`, `google_sign_in`, an auth/backend SDK (decision pending), `firebase_messaging` or equivalent for push (decision pending), `permission_handler`, `freezed` + `json_serializable` (models), `decimal` (parsing user-entered amounts). Check current versions on pub.dev when adding. Bundle Inter locally instead of `google_fonts` runtime fetching.

---

## 13. Milestones and prompts to give opencode

Work in this order. Give the agent **one prompt at a time**, review on an emulator, then continue. Each prompt assumes the agent has read this file and the PRD.

**M0 — Project and theme foundation**
> Create a Flutter project `{{APP_NAME}}` (package name to be confirmed) with the folder structure in section 10. Implement the design tokens in section 3 exactly (colors, typography with bundled Inter and tabular figures, spacing, radii, motion) and a light `ThemeData` that uses only those tokens. Add the CI check that fails on hardcoded `Color(0x` or `fontSize:` outside `core/theme`. Add a debug-only "design gallery" screen that shows every token. Do not build features yet.

**M1 — Component library**
> Build every component in section 5 in `core/widgets/`, including the `Glass` widget from section 4 with a `GlassConfig.enabled` switch. Add widget and golden tests at text scale 1.0 and 1.3. Add the design gallery entries for each component and state (default, pressed, disabled, loading, error, selected).

**M2 — Welcome and onboarding UI (mock data)**
> Implement S0–S5 from section 6 with the shared layout, progress bar, shared-axis transitions, haptics, the role table and the copy deck (ARB). Persist `OnboardingDraft` with `shared_preferences` so killing the app resumes. Add the age gate with `kMinimumAge`. Use no backend yet. Add widget tests for each step and one integration test for the happy path.

**M3 — Account, verification, permissions, first batch**
> Implement S6–S10 and the Sign-in screen against an `AuthRepository` and `BatchRepository` interface with in-memory mock implementations. Include the notification priming sheet, currency picker sheet with search, invite sharing via `share_plus`, join-with-link flow, and all error and loading states from section 9.

**M4 — App shell and Home**
> Implement the floating glass bottom nav with the centre add button, the router with auth/onboarding guards, and the Home screen from 7.1 using mock data, including the new-user empty state and coach marks.

**M5 — Quick Add and expense flows**
> Implement the Quick Add sheet (7.2) and the Full Expense Form, backed by the pure-Dart calculation engine in `domain/` with tests for equal, custom amount and percentage splits, validation, and rounding (leftover minor unit rule is an open PRD decision: make it a single swappable function and use "assign the remainder to the payer" as a temporary default, clearly marked TODO).

**M6 — Batches, balances, settle up**
> Implement Batch detail (7.3), Expense detail (7.4), the Settle up sheet (7.5, full amount only, both methods, correct labels and chips) and the dispute flow (PRD §10), all reading balances from the engine.

**M7 — Recurring, reports, activity, profile**
> Implement recurring expense configuration with custom intervals (every N days, weeks, months), the Activity feed, Reports (date and category summaries), Profile and account deletion with anonymisation messaging.

**M8 — Backend integration and hardening**
> Replace mock repositories with the chosen backend. Enforce permissions server-side, idempotent recurring generation, atomic settlement updates (PRD §15). Run the full checklist in sections 8 and 11 and fix every issue.

### 13.1 Prompt template for any later change

> Task: <what>. Read `AGENTS.md` and `PRD.md`. Use only tokens and components from `core/theme` and `core/widgets`; if a component is missing, add it there first. Cover loading, empty, error and offline states. Add tests. Run `flutter analyze` and the tests, then summarise what changed and list anything you were unsure about.

---

## 14. Definition of done for any screen

- [ ] Matches tokens: no hardcoded colours, sizes, durations.
- [ ] White background, no gradients, no neon, no heavy shadows.
- [ ] Exactly one primary action, pinned at the bottom, 56 high.
- [ ] Type hierarchy follows section 3.2 (one `headline`, sensible weights).
- [ ] Loading, empty, error, offline states exist.
- [ ] Works at 360×800 and 412×915, text scale 1.3, with keyboard open.
- [ ] TalkBack labels, 48 dp targets, AA contrast, reduce-motion handled.
- [ ] Glass used only on floating layers and has a solid fallback.
- [ ] Strings in ARB; no hardcoded text.
- [ ] Tests and goldens added; `flutter analyze` clean.

## 15. Open items for the human to decide

1. **App name** (replace `{{APP_NAME}}`).
2. **Minimum age** (default 18; legal confirmation needed for under-18 users).
3. **Backend** (Firebase vs Supabase vs custom) and push provider.
4. Confirm the **role list** and what "accordingly" should personalise.
5. Provide Mobbin reference screenshots in `design/references/` for the screens you care most about (Welcome, birthday picker, Quick Add, Home).
6. Remaining PRD open decisions (rounding remainder rule, settlement mismatch behaviour, currency change after expenses exist, recurring month-end rule).
