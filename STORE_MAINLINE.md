# STORE_MAINLINE — Solana dApp Store mainline plan (Phase D, promoted)

Promoted from "release-package draft" to a mainline workstream by user
order, 2026-10-25 20:18. Source of truth for requirements =
**docs.solanamobile.com as of 2026-10-25** (the dApp Store docs were
revised 2026-10-22 → 2026-10-24; page dates cited per requirement).
This file = gap audit + milestone schedule. Nothing in here authorizes
submission: the publish action still stops at the user gate in §4.

## 0. Headline finding — the flow changed

The current docs describe a **Publisher-Portal-first** flow
(publish.solanamobile.com): sign up → publisher profile → **KYC/KYB
identity verification** → connect publisher wallet → enter dApp
details (Save mints the **App NFT**) → Releases → upload signed APK →
Submit → In Review (result by email in ~3–4 business days).

The `config.yaml` CLI flow staged in `store/config.yaml`'s header
(`validate → create publisher → create app → create release →
publish submit`, three NFT mints) is the **legacy** flow: it survives
in the `solana-mobile/dapp-publishing` repo, but the current docs'
CLI page describes a different, portal-backed CLI that only
publishes *new versions* of an app that **already exists in the
portal** (App NFT minted) using a portal API key + signer keypair.
Plan of record is therefore the portal flow; `store/config.yaml`
remains the content source for the portal form (catalog copy,
testing instructions, asset paths), not a submission vehicle.

Sources: [S1] Submit a New App, [S4] dApp Publishing CLI,
[S5] dApp Store overview (full URLs in §5).

## 1. Requirement-by-requirement gap audit

Legend: ✅ compliant · 🔧 fixable by us (no user action) · 🚪 user gate.

### Portal / account layer
| # | Requirement (source) | Status |
|---|---|---|
| R1 | Portal account: sign up with email + name + password, email-code login ([S1] §1) | 🚪 not done — account & password are the user's |
| R2 | Publisher profile: individual vs organization + name + **publicly reachable website** about the app/company/developer ([S1] §2) | 🚪 not done — entity choice + website are the user's |
| R3 | **KYC (individual) / KYB (organization) approved before a dApp can be added**; may be skipped at profile creation but blocks app creation ([S1] §3) | 🚪 not done — identity documents, inherently personal. **New vs the Phase D draft's assumptions** |
| R4 | Publisher wallet: browser-extension wallet, **a new wallet used only for publishing**, funded with a small amount of SOL for mint fees ([S1] Before-you-begin, §4) | 🚪 not done — the pre-agreed user gate (never a main/trading wallet) |
| R5 | Review Publisher Policy + Developer Agreement before submitting ([S1]) | 🔧 policy read & audited in this pass; agreement acceptance happens by the user at submission |

### App / listing layer
| # | Requirement (source) | Status |
|---|---|---|
| R6 | Package name exactly matches the APK applicationId, case-sensitive, unused by another app, immutable afterwards ([S1] §5) | ✅ `com.spritebonk.game` — aapt2-verified against the signed APK 2026-10-25 (uniqueness only confirmable in the portal) |
| R7 | Listing is an on-chain NFT record: **App NFT minted when the dApp details are saved**; the release is published onchain at release submission ([S1] §5–6, [S5]) | 🚪 pending R1–R4 (this replaces the legacy publisher/app/release three-mint sequence) |
| R8 | Support email + contact email on the listing; website / terms / privacy links each a **public HTTPS page, portal-checked** ([S1] §5, [S2] App Info) | 🚪 fields blank in config (`TODO_PUBLISHER`) — values are the user's; drafting the pages is ours (R9/R10) |
| R9 | Privacy policy on its own public HTTPS page ([S1]); policy also requires disclosing user-data practices in it ([S6] User Data) | 🔧+🚪 no page exists. Draft content is ours (app stores the pasted wallet address locally in `user://wallet.cfg`, queries public RPC for balance, has **no account system** → no account-deletion duty, no server-side user data); the hosted URL is the user's |
| R10 | Terms of service on its own public HTTPS page ([S1]) | 🔧+🚪 same split as R9 |

### Listing assets & copy
| # | Requirement (source) | Status |
|---|---|---|
| R11 | Icon 512×512 **with a background color, no transparency** ([S1], [S2]) | ✅ `store/media/icon-512.png` + `publisher-icon-512.png` are 512×512 RGB, opaque (verified 2026-10-25) |
| R12 | **Banner 1200×600** ([S1], [S2]) | 🔧 **missing entirely** — produce from in-game art |
| R13 | Screenshots: **4–8** items, JPG/PNG/GIF/WebP, ≤3 MB each, all the same dimensions, first item sets orientation (9:16 or 16:9) ([S2]) | ✅ 4 × PNG, 1280×720, ~0.6 MB each |
| R14 | Screenshot resolution **≥1080 px in width and height recommended** ([S2]) | 🔧 1280×720 fails the recommendation on height (720 < 1080) — re-render at 1920×1080; recommendation, not a hard rule |
| R15 | App name ≤ 25 characters ([S2]) | ✅ "SpriteBonk" (10) |
| R16 | Short description ≤ **50 characters** ([S2]) | 🔧 en-US draft is **108 chars — over the limit**; zh-CN is 32 ✓. Rewrite en ≤50 (copy is re-entered in the portal form anyway) |
| R17 | Long description + per-release "What's New" present ([S2]) | ✅ en-US + zh-CN drafts exist in config.yaml and carry over to the portal form |

### APK layer
| # | Requirement (source) | Status |
|---|---|---|
| R18 | Release-signed APK; **debug builds rejected** ([S1], [S3]) | ✅ signed release; cert SHA-256 `b05b80e1…a232` **re-verified 2026-10-25 on the current hotfix APK** (48,168,986 B) |
| R19 | Must support **arm64-v8a** ([S1]) | ✅ APK native-code = arm64-v8a only |
| R20 | APK ≤ 2 GB ([S1]) | ✅ 48 MB |
| R21 | All updates signed with the **same key**; every update needs a **higher versionCode** ([S3]) | ✅ process in place (local keystore + `android/build_apk.sh`); versionCode currently 1 |
| R22 | App must actually run for review; portal takes testing instructions ([S1] §6, config portal section) | ✅ testing instructions drafted (guest play + optional read-only connect). Note: final store build must be the post-IP-swap build (R23) — re-run the Seeker pass on that exact APK at M7 |

### Content / policy layer ([S6] Publisher Policy)
| # | Requirement (source) | Status |
|---|---|---|
| R23 | **No third-party IP infringement; no content creating a likelihood of confusion with a third party's brand/products** (Restricted Content → Illegality / Deliberately Misleading) | 🔧 **HARD GATE — currently failing.** The build and the listing copy still use Pokémon IP as development placeholders (species names/models; "Viridian Forest", Scyther/Pinsir/Nidoking, Vine Whip/Ember/Water Gun in the catalog text). Per the standing user ruling these are reference/placeholder only and must be swapped for own IP before a monetized launch; for the store this is a policy gate, not a paperwork item. Blocks submission until M3 |
| R24 | No misleading claims about the app's nature/purpose; regulated financial services must supply legally required documentation (Restricted Activities) | ✅ for **this** release: copy states "$SPRT token and Genesis NFT eligibility are planned for a later season update and are **not part of this release**"; the build has no transactions, no signing, no token sale. ⚠️ Re-audit mandatory before any release that adds $SPRT/Genesis purchase or claim flows — that is when token/NFT elements can trigger the financial-services documentation duty. The store imposes **no separate token/NFT pre-approval** in the current docs |
| R25 | User-data transparency: disclose collection/use in the privacy policy; don't collect minors' data without parental consent; no deceptive consent flows ([S6]) | 🔧 covered by the R9 draft: local-only address storage + public-RPC balance reads, no accounts, no analytics SDKs. Nothing to disclose server-side because there is no server |

### Wallet / MWA — special callout (see also §3)
| # | Requirement (source) | Status |
|---|---|---|
| R26 | MWA is the standard Android wallet-connect protocol ([S7]); **no current publishing document makes MWA — or any wallet connection — a submission requirement** ([S1], [S2], [S6] contain no such clause; the web-app publishing guide states apps that do not connect to a wallet can skip wallet steps entirely, [S8]) | 🔧 gap is **UX-grade, not a gate**: guest default + documented manual-address read-only connect is submittable as-is, provided the listing/testing instructions describe it honestly (they do). One-tap MWA authorize remains a mainline item (M4) and a hard prerequisite only for future token/NFT features |

### Process
| # | Requirement (source) | Status |
|---|---|---|
| R27 | Review: results by developer email from publishersupport@dappstore.solanamobile.com, typically 3–4 business days; broken links are a named common rejection reason ([S1], [S2]) | ℹ️ informational — plan the M7 wait around it; re-check every URL the day of submission |
| R28 | Subsequent versions may be published with the **portal-backed CLI**: app pre-created in portal + portal API key (`DAPP_STORE_API_KEY`) + signer keypair ([S4]) | 🔧 future (M9); supersedes the legacy CLI commands staged in config.yaml's header |

**Counts: 28 requirements — ✅ compliant 11 (R6, R11, R13, R15, R17, R18, R19, R20, R21, R22, R24) · 🔧 fixable by us 9 (R5, R12, R14, R16, R23, R25, R26, R28 + drafting halves of R9/R10) · 🚪 user gate 8 (R1, R2, R3, R4, R7, R8 + hosting halves of R9/R10).**

## 2. The three gaps that matter most

1. **R23 — IP swap is the real critical path.** Everything else is
   days of work; this one is a content rebuild (species, names,
   listing copy) and it is a hard policy gate. It also invalidates
   the current screenshots/banner art, so asset work (M1) must use
   post-swap material or be redone.
2. **The submission flow itself changed (R3/R7/R28).** The Phase D
   draft aimed at a legacy CLI flow and did not know about
   **KYC/KYB**: nobody can even create the app in the portal until
   the user's identity verification is approved. The user gate got
   bigger, not smaller — plan for it early, in parallel with M1–M3.
3. **R12 + R16 — listing assets/copy are not actually ready.**
   No 1200×600 banner exists, and the en-US short description is
   2× the 50-char limit. Small, certain rejections if submitted
   as-is ("broken/incomplete listing" class), both cheap to fix.

## 3. MWA verdict (official-docs basis)

**Not a submission hard gate — submit-then-patch is viable.**
- [S1] (the submission checklist) and [S2] (listing requirements)
  contain no wallet-integration requirement at all; [S6] has no
  MWA clause. [S8] states the general rule explicitly for web apps:
  apps that do not connect to a wallet skip wallet steps — wallet
  connection is a feature choice, not a store requirement.
- What review *will* test is that the app behaves as its listing
  and testing instructions describe. Ours describe guest play +
  optional manual-address read-only connect accurately
  (`solana_mobile_dapp_publisher_portal.testing_instructions`), and
  `request_authorize()` fails closed with a clear reason string
  (`scripts/wallet.gd`, ERR_MWA_UNAVAILABLE) instead of faking a
  one-tap flow — that honesty is what keeps R24/R26 green.
- Caveats: (a) on a Seeker, "connect wallet" that asks for a pasted
  address is visibly below the platform's UX norm ([S7] positions
  MWA as *the* Android standard) — expect it to be the first
  post-launch fix regardless; (b) MWA `authorize` identity needs an
  identity URI (app website) + icon, so M4 completion depends on
  the R2/R8 website decision; (c) MWA becomes a **hard
  prerequisite** the moment any $SPRT/Genesis transaction feature
  ships (R24 re-audit point).

## 4. Milestone schedule

| MS | What | Acceptance criteria | Depends on | User gate? |
|---|---|---|---|---|
| M1 | Listing assets v2: banner 1200×600; screenshots re-rendered 1920×1080 ×4–8; en short description rewritten ≤50 chars (both locales re-checked) | Files land in `store/media/` + `store/screenshots/`; a checker pass prints each asset's dimensions/size against [S2] and all pass; **use post-M3 art if M3 lands first** | — (art source: M3) | No |
| M2 | Legal pages drafted: privacy policy + terms of service text, matching actual app behavior (local address storage, public-RPC reads, no accounts/analytics) | Drafts in `store/legal/`; every data claim in the drafts traceable to `scripts/wallet.gd` / `scripts/profile.gd` behavior; no placeholder claims | — | No (hosting is M5) |
| M3 | **IP swap gate**: all third-party species/names/copy/art replaced with own IP across game + listing | Grep of APK contents + store copy for third-party marks = 0 hits; R23 re-audit written into this file; new store build produced from the swapped tree | A-line asset work | No |
| M4 | MWA one-tap authorize on the production path (fills `request_authorize()` only) | Seeker real-device authorize round-trip succeeds and is recorded (wallet address returned, no freeze); manual-entry fallback still works; guest flow untouched | R2 website (identity URI) helps; can prototype before | No |
| M5 | **User gate package** (user only, start early — KYC lead time): portal signup; entity choice + KYC/KYB approval; dedicated publisher wallet + small SOL; website live; privacy/ToS pages hosted at public HTTPS URLs; contact + support emails | Portal profile shows KYC/KYB approved; wallet connected; all URLs return 200 over HTTPS | M2 (page texts) | **Yes — the designated stop** |
| M6 | Create the app in the portal: form filled from `store/config.yaml` content; Save → **App NFT minted** | App NFT mint address recorded (into config.yaml `app.address` as a record + PHASES.md Phase D line); package name locked to `com.spritebonk.game` | M5 | Yes (wallet approvals) |
| M7 | First release submission: upload final post-M3 APK, What's New, testing instructions → Submit → **In Review** | Portal status = In Review; the exact submitted APK re-passed the Seeker device pass (boot, touch, guest run) before upload | M1, M3, M6 | Yes (wallet approvals) |
| M8 | Review follow-through & go-live: answer review inquiries (Discord #dev-answers if >5 business days), verify the live listing from a Seeker's dApp Store | Listing live; listing URL + approval email date recorded in PHASES.md | M7 | Partially |
| M9 | Version channel: portal API key + current `dapp-store` CLI wired for subsequent releases; versionCode-bump discipline documented | A dry version bump builds, signs with the same cert, and is CLI-ready without minting anything | M6 | No |

## 5. Sources (docs.solanamobile.com unless noted; fetched 2026-10-25)

- [S1] Submit a New App — https://docs.solanamobile.com/dapp-store/submit-new-app (updated 2026-10-24)
- [S2] Listing Page Guidelines — https://docs.solanamobile.com/dapp-store/listing-page-guidelines (modified 2026-10-24)
- [S3] Build and Sign an APK — https://docs.solanamobile.com/dapp-store/build-and-sign-an-apk (modified 2026-10-24)
- [S4] dApp Publishing CLI — https://docs.solanamobile.com/dapp-store/publishing-cli (modified 2026-10-22)
- [S5] dApp Store overview — https://docs.solanamobile.com/solana-mobile-stack/dapp-store (modified 2026-10-22)
- [S6] Publisher Policy — https://www.solanamobile.com/publisher-policy-web (linked from https://docs.solanamobile.com/dapp-store/publisher-policy)
- [S7] Mobile Wallet Adapter overview — https://docs.solanamobile.com/solana-mobile-stack/mobile-wallet-adapter ; MWA for Mobile Apps — https://docs.solanamobile.com/mobile-wallet-adapter/mobile-apps
- [S8] Publishing a Web App on the dApp Store — https://docs.solanamobile.com/recipes/general/publishing-a-web-app (updated 2026-10-22)

Local evidence: `store/config.yaml`, `store/media/`, `store/screenshots/`
(file dimensions/sizes measured 2026-10-25); APK badging + signature
re-verified 2026-10-25 (`aapt2 dump badging`, `apksigner verify` —
package com.spritebonk.game, v1.0.0/vc1, minSdk 21, targetSdk 34,
native-code arm64-v8a, permissions INTERNET + ACCESS_NETWORK_STATE,
cert SHA-256 b05b80e1…a232); `scripts/wallet.gd` (MWA seam,
ERR_MWA_UNAVAILABLE); PHASES.md Phase B/C/D records.
