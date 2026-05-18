# Play Content Rating — Questionnaire Answers

The Play Console rating wizard (IARC) asks ~25 yes/no questions to derive a
PEGI / ESRB / USK / ClassInd rating. Use the answers below to get a clean
**Everyone / PEGI 3 / USK 0 / 全年齡** rating.

> Path in console: **App content → Content rating → Start questionnaire**.

## Step 1: Category

Select **Social Networking / Communication** (closest fit — not "Reference",
not "Games", not "Dating" — dating-app category triggers stricter review).

## Step 2: Questionnaire

| # | Question (paraphrased) | Answer | Rationale |
|---|---|---|---|
| 1 | Violence — does the app reference, depict, or contain any violence? | **No** | UI is messaging only |
| 2 | Realistic violence | **No** | n/a |
| 3 | Fantasy violence | **No** | n/a |
| 4 | Sexuality — kissing, romance, sexual content | **No** | App is for couples but contains no sexual content itself |
| 5 | Nudity | **No** | User-generated photos are E2EE, never seen by us, but we set the app's own content to "no" |
| 6 | Profanity / crude humour | **No** | None in our UI strings |
| 7 | Substances — alcohol, tobacco, drugs | **No** | None |
| 8 | Gambling / simulated gambling | **No** | None |
| 9 | Horror / fear themes | **No** | None |
| 10 | Crime references | **No** | None |
| 11 | Discrimination | **No** | None |
| 12 | Sharing user location with other users | **No** | We do not collect location at all |
| 13 | Allows users to interact / communicate | **Yes** | Core feature — chat between paired couple |
| 14 | … and is the interaction unrestricted (any user → any user)? | **No** | Strictly 1-to-1, locked to the paired partner; no discovery, no group, no DMs to strangers |
| 15 | Allows sharing of user-generated content publicly | **No** | All content stays between the two paired users |
| 16 | Allows users to purchase digital goods | **No** | No IAP in v1.5.x |
| 17 | Shares user data with third parties | **No** | We do not share user data |
| 18 | Tracks or collects sensitive user info (financial, health, etc.) | **No** | We collect only email for sign-in |
| 19 | Targets children under 13 | **No** | App is for adult couples; age-gated in onboarding (Phase E item) |

## Step 3: Result

Expect **Everyone (ESRB) / PEGI 3 / USK 0 / 全年齡 (CERO A)**.

If Play flags the app as Teen+ because of question 13 (user interaction), add
in the **Additional details** free-text box:

> "Communication is strictly limited to the user's single paired partner.
> There is no discovery, friend list, group chat, or stranger interaction.
> Each user can only chat with one other person (their pair) and unpair
> requires explicit consent from both sides."

That justification usually drops the rating back to Everyone.

## Step 4: Save + apply

Click **Save questionnaire** → **Apply rating** → the rating now appears on
the listing.

## Re-rating

Required again any time the app starts collecting new data categories or
adds new interaction modes (e.g. if Phase E adds group chats or open
discovery).
