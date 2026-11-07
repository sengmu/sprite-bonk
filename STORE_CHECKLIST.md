# STORE_CHECKLIST — Solana Mobile dApp Store requirements vs. SpriteBonk state

Compiled 2026-10-26 (read-only audit). Requirements sourced from the
official docs **as fetched today, 2026-10-26** (the docs pages carry
"Updated 2026-10-26 / 2026-10-24" stamps); every row cites its doc URL.
This supersedes the requirement layer of STORE_MAINLINE.md
(2026-10-25) — its milestone plan (M1–M9) still stands; deltas vs.
that audit are marked ◆.

**State audited**: project tree as of 2026-10-26 ~15:40 CST. APK on
disk = Cycle 17 build, 57,483,124 B, sha256 `8505b8a7…`, cert
`b05b80e1…a232` (apksigner/aapt re-verified in this pass). **Cycle 18
(UI round 2 + shop-item wiring) is editing the tree right now** — rows
about in-build behaviour describe the shipped Cycle 17 APK and must be
re-checked against the final store build.

Legend: ✅ SATISFIED · ⛔ GAP · 🚪 USER-GATED · ❓ UNKNOWN

**Counts: 40 requirements — ✅ 25 · ⛔ 8 · 🚪 4 · ❓ 3**

---

## A. Publisher / account layer

| # | Requirement | Source | Status | Evidence / notes |
|---|---|---|---|---|
| A1 | Publisher Portal account (email + name + password, email-code login) | [Submit a New App §1](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Done on the main line: portal account exists |
| A2 | Publisher profile: individual vs organization + name + publicly reachable website about the app/company/developer | [Submit §2](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Profile exists (individual, 林贵鸿）; website was locked at verification (main-line record). The *app-level* website is the neutral site (B2) |
| A3 | **KYC (individual) / KYB (org) approved before a dApp can be added** | [Submit §3](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Main-line record: account shows **Verified** (member since 2026-01-21). The gate that blocked app creation in earlier planning is clear |
| A4 | Publisher wallet: browser-extension wallet, **a new wallet used only for publishing**, funded with a small amount of SOL for mint fees; connect it in the portal | [Submit, Before-you-begin + §4](https://docs.solanamobile.com/dapp-store/submit-new-app) | 🚪 | Dedicated Phantom publisher wallet created and connected on the main line (`@musen123`). Remaining owner action: **fund it with a small amount of SOL** — fees only appear in the signing popup; the unsaved wizard draft also dies if that page is refreshed |
| A5 | Review the Publisher Policy and the Developer Agreement before submitting | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Agreement](https://docs.solanamobile.com/dapp-store/agreement) | 🚪 | Policy full text read and audited in this pass (see §E); formal acceptance is the owner's act at submission |

## B. App / listing metadata

| # | Requirement | Source | Status | Evidence / notes |
|---|---|---|---|---|
| B1 | Package name exactly matches the APK applicationId, case-sensitive, unused by another app, immutable after Save | [Submit §5](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | `com.spritebonk.game` — aapt-verified against the current signed APK in this pass; wizard draft accepted it (main line) |
| B2 | App website: public HTTPS page about the app | [Submit, Before-you-begin + §5](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Neutral site live: `spritebonk-site.musen-ai-9527.workers.dev` (/, /privacy, /terms) — /privacy and /terms fetched and read in this pass |
| B3 | Privacy policy on **its own** publicly reachable HTTPS page | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Live at the site's /privacy (EN + zh, effective 2026-10-25). Content verified line-by-line against actual app behaviour (local-only storage; optional pasted address → public RPC `getBalance`; no accounts/analytics/keys) |
| B4 | Terms of service on **its own** publicly reachable HTTPS page | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Live at the site's /terms (fetched in this pass); correctly states not-a-wallet / no transactions / future features are plans, not offers |
| B5 | Support email + contact email on the listing; every link portal-checked HTTPS | [Submit §5](https://docs.solanamobile.com/dapp-store/submit-new-app) | 🚪 | `linguihong000@gmail.com` entered in the wizard draft and the site URLs passed the portal's "Link looks good" check (main line) — but the draft is **not saved**; lands only when the owner clicks Save + signs (A4) |
| B6 | App name ≤ 25 characters | [Listing Page Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ✅ | "SpriteBonk" = 10 |
| B7 | Short description (subtitle) ≤ **50 characters** | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ | The config.yaml en-US draft is **108 chars — unusable**. A compliant 48-char candidate exists (`store/portal-prep/listing-fields.md`) and per the main line the wizard's subtitle field needs the ≤50 form confirmed at Save; zh-CN draft is 32 ✓ but contains an IP name (see B8). Metadata-only, cheap |
| B8 | Long description present, accurate overview of features | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ | Current draft (a) carries third-party IP — "Viridian Forest", Scyther/Pinsir/Nidoking, Vine Whip/Ember/Water Gun — blocked by E1; (b) is **stale**: describes a Zone-1-only game, while the shipped build runs the full 4-zone chain. Full rewrite at reskin |
| B9 | "What's New" text with each release | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) · [Submit §6](https://docs.solanamobile.com/dapp-store/submit-new-app) | ⛔ | Draft exists but carries the same IP name ("Viridian Forest" / 常磐森林） — rewrite with B8 |
| B10 | Icon **512×512 with a background color, no transparency** | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ✅ | Verified in this pass: `store/media/icon-512.png` and `publisher-icon-512.png` are 512×512 RGB, opaque; 512 icon also uploaded to the wizard draft (main line). ◆ Note: post-reskin the icon art itself must not carry third-party IP (E1) |
| B11 | **Banner 1200×600** | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ | **No banner file exists** — `store/media/` holds only the two icons; `store/portal-prep/banner-spec.md` is a spec, not an asset. A required asset; must be produced from **post-reskin** art |
| B12 | Screenshots: **4–8** items, JPG/PNG/GIF/WebP, ≤3 MB each, all the same dimensions, first item sets orientation (9:16 or 16:9) | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ | Count/format/size/uniformity pass (4 × PNG 1280×720, ~0.6 MB — measured in this pass), but the *content* is unusable: captured 2026-10-24 from a pre-UI-overhaul build and full of third-party IP. Must be recaptured from the final post-reskin store build (the wizard wants 4 × 9:16 previews per the main line) |
| B13 | Screenshot resolution ≥1080 px in width **and** height — *recommended* | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ (soft) | Current set is 1280×720 (height fails the recommendation; it is a recommendation, not a hard rule). Recapture at 1920×1080 (or 1080×1920) with B12 |
| B14 | Preview video: optional; if used, 1080p recommended, .mp4 ≤30 MB | [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ✅ (n/a) | Optional — none planned for v1 |

## C. APK technical requirements

| # | Requirement | Source | Status | Evidence / notes |
|---|---|---|---|---|
| C1 | Release APK signed with your release key; **debug builds are rejected** | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Build and Sign an APK](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk) | ✅ | apksigner-verified in this pass on the current APK; release cert `b05b80e1…a232`; no debuggable flag in badging |
| C2 | APK must support **arm64-v8a** | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | `native-code: 'arm64-v8a'` only (badging, this pass); export preset enables arm64-v8a exclusively |
| C3 | APK at most **2 GB** | [Submit, Before-you-begin](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | 57,483,124 B |
| C4 | Each app has its own signing key, stored securely; **all future updates signed with the same key** | [Build and Sign an APK](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk) | ✅ | Project-dedicated keystore (`android/spritebonk.keystore`); the cert has been identical across every build to date. Never used for Google Play (a separate key would be required there, per the Play cross-publishing doc) |
| C5 | Every update needs a **higher versionCode** | [Build and Sign](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk) · [Submit an Update](https://docs.solanamobile.com/dapp-store/submit-an-update.md) | ✅ | Process in place (`android/build_apk.sh`); versionCode 1 / versionName 1.0.0 is correct for the first release |
| C6 | No minimum/target SDK bar is published in the current submission docs | [Submit](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Build and Sign](https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk) | ✅ | For the record: minSdk 21 / targetSdk 34 / compileSdk 34 (badging, this pass). Nothing in today's docs sets an SDK floor — if the portal validator imposes one it will surface at upload (see F3) |
| C7 | Save mints the **App NFT**; Submit publishes the release onchain; review then runs ~3–4 business days, result by developer email | [Submit §5–6 + After Submission](https://docs.solanamobile.com/dapp-store/submit-new-app) | 🚪 | Owner's wallet signatures (A4). Broken links are a named common rejection reason — re-check every URL on submission day |

## D. Review-facing behaviour of the build itself

| # | Requirement | Source | Status | Evidence / notes |
|---|---|---|---|---|
| D1 | The app must actually run and behave as its listing + testing instructions describe (review installs and plays it) | [Checklist](https://docs.solanamobile.com/dapp-store/checklist) · [Listing Guidelines, App Info](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) | ⛔ | Core game: extensively verified (260-check suite, Linux-export boot smoke, owner plays it on a Seeker). **But in the shipped Cycle 17 APK the daily shop's six items can be bought while their in-run effects and the bring-in flow have no consumer** — same class as the Lab 'bag' row (both noted since Cycle 16). A reviewer who buys one sees nothing happen = dead-feature / misleading-functionality risk. **Cycle 18 is wiring this right now**; the final store build must prove buy → bring-in → effect through the real path |
| D2 | Testing instructions supplied with the release | [Submit §6](https://docs.solanamobile.com/dapp-store/submit-new-app) | ✅ | Drafted and accurate (`store/config.yaml`): guest play needs no account/wallet; optional read-only connect via pasted address; no transactions possible. Paste into the portal release form at submission |
| D3 | If content is gated, provide App Review a full-access test account | [Checklist](https://docs.solanamobile.com/dapp-store/checklist) | ✅ (n/a) | Nothing is gated — guest mode is the full game |

## E. Publisher Policy — content & conduct

Policy full text: https://solanamobile.com/publisher-policy-web
(linked from https://docs.solanamobile.com/dapp-store/publisher-policy)

| # | Requirement | Status | Evidence / notes |
|---|---|---|---|
| E1 | **No content that infringes third-party IP; no content designed to create a likelihood of confusion with a third party's brand/products** (Restricted Content → Illegality; Deliberately Misleading) | ⛔ **HARDEST BLOCKER** | The shipped APK still contains the original game's IP as dev placeholders: species roster/names/models and data files (raw-byte markers found in this pass inside the APK: `pokemon.json` ×2, `Scyther` ×1 — the PCK compresses most content, so raw grep *undercounts*), plus IP names throughout the listing copy (B8/B9) and in the current screenshots (B12). The standing reskin gate (replace all names/art/copy with own IP, then re-audit) must zero this in **build + copy + assets** before submission. Submitting as-is invites rejection under this clause |
| E2 | No deliberately misleading content; no false affiliation/endorsement claims | ✅ | Listing + terms explicitly frame $SPRT / Genesis NFT as *planned, not part of this release, not offers*. In-app, the token hooks in `scripts/wallet.gd` are non-functional stubs that are **not surfaced as working features** |
| E3 | User-data guidelines: disclose collection/use in a privacy policy; no collecting minors' data without parental consent; no deceptive consent; **provide a means to delete account + associated data** | ✅ | No accounts, no server, no analytics (APK permissions: INTERNET + ACCESS_NETWORK_STATE only). Disclosure is live (B3); deletion = in-app wallet disconnect (erases the saved address) + uninstall (erases all local data), documented in policy §5. Address is stored only in `user://wallet.cfg` (`scripts/wallet.gd`, read in this pass) |
| E4 | Regulated Data: collect none, or comply fully (gov IDs, health, biometrics, precise geolocation, credentials…) | ✅ | None collected — no location/camera/contacts permissions in the APK (badging, this pass) |
| E5 | Restricted activities: dApps providing regulated financial services must supply legally required documentation; no malicious/vulnerability-exploiting code; no interference with devices/networks | ✅ for **this release** | This build cannot sign or transact at all — no financial service is provided. ⚠️ **Re-audit is mandatory before any release that adds $SPRT/Genesis purchase or claim flows**; that is when the documentation duty can attach. Today's docs impose no separate token/NFT pre-approval |
| E6 | User-generated content duties (terms parity, reporting, moderation, block) | ✅ (n/a) | Single-player game; no UGC surface exists |
| E7 | In-game "slots" prop (Cycle 15) | ✅ (noted) | Pays/plays in in-game gold only; there is no purchase path, no cash value, no cash-out in this release — not real-money gambling, and no clause in the current policy names virtual-currency game mechanics. Re-check if monetisation ever touches it |

## F. Wallet / MWA expectations

| # | Requirement | Source | Status | Evidence / notes |
|---|---|---|---|---|
| F1 | **MWA (or any wallet integration) is a submission requirement** | [Submit](https://docs.solanamobile.com/dapp-store/submit-new-app) · [Listing Guidelines](https://docs.solanamobile.com/dapp-store/listing-page-guidelines) · [Publisher Policy](https://solanamobile.com/publisher-policy-web) | ✅ **Not required** | No clause in any current publishing document mandates wallet integration; the web-app guide states the general rule explicitly — apps that do not connect to a wallet skip the wallet steps ([Publishing a Web App](https://docs.solanamobile.com/recipes/general/publishing-a-web-app)). Our read-only address connect, described honestly in the listing (B8) and testing instructions (D2), is submittable as-is |
| F2 | If using MWA, test connect + signing flows with popular wallets (Phantom, Solflare) | [Checklist](https://docs.solanamobile.com/dapp-store/checklist) | ✅ (n/a today) | Applies when MWA lands. Current build: `request_authorize()` in `scripts/wallet.gd` fails closed (`ERR_MWA_UNAVAILABLE`) and the UI falls back to manual address entry — no fake one-tap flow. **UX-grade gap, not a gate**: on a Seeker, paste-an-address is visibly below the platform norm, and MWA becomes a hard functional prerequisite the moment any token/NFT transaction feature ships (E5) |
| F3 | In-app access to the privacy policy | — | ❓ | **No current doc requires an in-app link** (the listing's App Info section carries the links, B3/B4). The app currently has **no** in-app privacy/terms entry (grep-verified in this pass). What settles it: the portal form (if it asks) or review feedback. Cheap insurance: add an in-app link in a UI cycle |
| F4 | Content / age rating step | — | ❓ | No rating questionnaire appears anywhere in the current publishing docs or portal-flow description. What settles it: the owner completing the portal form — if a rating step exists, it appears there |
| F5 | Behaviour when the public RPC is unreachable (wallet view) | — | ❓ | Not a documented criterion. Current behaviour: the balance read fails silently and the view simply doesn't update (`scripts/wallet.gd` `_on_rpc_completed`). Cosmetic; worth a visible "couldn't refresh" state for polish, not a store bar |

---

## Build-itself GAPs, ranked by submission-blocking power

(Functional implications for the game build — portal/metadata gaps are
in the tables above: B11 banner, B12/B13 screenshot recapture, B7–B9
copy rewrite. All of those *also* depend on the reskin for their art
and names.)

1. **E1 — Third-party IP inside the APK.** Hard policy blocker.
   Species names/roster/models/data and in-game copy must be fully
   swapped for own IP and the APK re-grepped clean (names, data-file
   names, strings), exactly as the standing reskin gate prescribes.
   Nothing else in this list matters until this is zero.
2. **D1 — Purchasable shop items with no in-run effect** (daily-shop
   six items + Lab 'bag' row) in the currently shipped APK. A
   review-visible dead feature and a misleading-functionality risk.
   Cycle 18 (in flight now) is wiring buy → bring-in → effect; the
   store build must ship only after that path is harness-proven
   end-to-end. If it slips, the safer submission build hides the
   purchase surface rather than selling no-ops.
3. **F3 — No in-app privacy/terms entry** (❓, not documented as
   required). One small UI addition removes the whole question;
   recommended in the next UI cycle regardless of the answer.
4. **F5 — Silent RPC-failure in the wallet view** (❓/cosmetic).
   A visible refresh-failure state keeps a reviewer from reading
   the wallet view as broken.

**Submission cannot start** until #1 is zero and B11/B12 assets exist
in post-reskin form; it should not start until #2 is closed in the
exact APK being uploaded. Everything else on this list is either done,
owner-gated at the portal (A4/A5/B5/C7 — wallet SOL, Save + sign), or
a cheap copy/asset fix (B7–B9, B13).

## Sources (fetched 2026-10-26)

- Submit a New App — https://docs.solanamobile.com/dapp-store/submit-new-app (Updated 2026-10-26)
- Build and Sign an APK — https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk (modified 2026-10-26)
- Listing Page Guidelines — https://docs.solanamobile.com/dapp-store/listing-page-guidelines (modified 2026-10-26)
- Publishing Journey Checklist — https://docs.solanamobile.com/dapp-store/checklist (modified 2026-10-26)
- dApp Store intro — https://docs.solanamobile.com/dapp-store/intro (modified 2026-10-26)
- Publisher Policy (full text) — https://solanamobile.com/publisher-policy-web
- Publishing a Web App on the dApp Store — https://docs.solanamobile.com/recipes/general/publishing-a-web-app (updated 2026-10-22)
- Submit an Update — https://docs.solanamobile.com/dapp-store/submit-an-update.md
- Developer hub — https://solanamobile.com/developers

Local evidence: `STORE_MAINLINE.md` (2026-10-25 audit, R1–R28),
`store/config.yaml`, `store/portal-prep/{listing-fields,banner-spec,
privacy-policy-draft,terms-draft}.md`, `store/media/` +
`store/screenshots/` (dimensions measured in this pass),
`export_presets.cfg`, `project.godot`, `scripts/wallet.gd`,
APK badging + apksigner + raw-byte IP scan (this pass), live fetches
of the site's /privacy and /terms pages (this pass).
