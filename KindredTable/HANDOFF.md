# KindredTable — Handoff (pick up here)

Last updated 2026-08-25. This doc travels with the repo so any machine (or a fresh
Claude) can continue without prior chat context.

## What this is
KindredTable — iOS app: photograph your fridge/pantry → Gemini identifies
ingredients → taste-matched recipes. Part of the "Kindred" family.

- **Repo:** `chuckg73-create/chuckg73-create.github.io` (PUBLIC). The app is the
  `KindredTable/` subfolder; the repo also hosts the marketing site.
- **Active branch:** `claude/kindredtable-ios-app-j64935` (all app work). `main` = website only.
- **Xcode project:** `KindredTable/KindredTable.xcodeproj` · scheme `KindredTable`
- **Bundle ID:** `com.kindred.KindredTable` (must match the existing App Store Connect
  record — do NOT change it to AgileInABox.*; that caused upload 409s).
- **Team:** Z7H7ZD8D7X (Charles Gallagher) · **Display name:** KindredTable
- **Current version:** 3.0 (latest build was 12; bump the build number for each new upload).
- **Marketing site (live):** https://chuckg73-create.github.io/
  - Support:  https://chuckg73-create.github.io/kindredkitchen/support.html
  - Privacy:  https://chuckg73-create.github.io/kindredkitchen/privacy.html

## Set up on a new Mac
```bash
git clone https://github.com/chuckg73-create/chuckg73-create.github.io.git
cd chuckg73-create.github.io
git checkout claude/kindredtable-ios-app-j64935
open KindredTable/KindredTable.xcodeproj
```
Then:
1. **Gemini key** — `KindredTable/Secrets.xcconfig` is gitignored (NOT in the repo).
   Copy it over (AirDrop from the old Mac) OR: `cp KindredTable/Secrets.example.xcconfig
   KindredTable/Secrets.xcconfig` and paste your key. Without it the app runs in
   offline "sample" mode.
2. **Use the RELEASE Xcode** (/Applications/Xcode.app), NOT an Xcode beta — Apple
   rejects App Store builds made with beta Xcode.
3. Archives don't transfer between Macs — just Product ▸ Archive fresh on this machine.

## To submit 3.0 to the App Store
The ASC app record "KindredTable" already exists (bundle com.kindred.KindredTable).
1. Bump build number, Product ▸ Archive (release Xcode).
2. Organizer → Distribute App → App Store Connect → Upload. It ATTACHES to the
   existing record — do not let Xcode "create" a new app (that 409s on the name).
3. In App Store Connect: set version 3.0, paste the listing from
   `KindredTable/AppStore/metadata-3.0.md`, set the Support + Privacy URLs above,
   add 6.5" screenshots (grab via TestFlight on-device).
4. Submit for review.

## What 3.0 contains
Fridge/pantry scan → taste-matched ideas · **taste flywheel** (rate cooked dishes →
learns; loved auto-saves) · **auto-plan my week** · family cookbook (photo + web-link
import, editable) · scale any recipe · nutrition · ingredient substitution · Cook Mode
(voice + per-step timers) · cook-by-time reminders · meal planner + consolidated
grocery · use-it-up · cookbook search · recipe notes · scan-my-kitchen equipment ·
cooking-together taste blend · dish images · "no shopping" filter · warm palette.

## Gotchas / durable facts
- Recipe generation `maxOutputTokens` = 20000 (6+ rich recipes truncated at 8192 →
  "Couldn't load ideas"). Recipe request timeout = 90s (7-recipe auto-plan).
- `~/Documents/KindredKitchen` on the old Mac is a DEAD empty scaffold (bundle
  AgileInABox.KindredKitchen, 1.0). Ignore it — the real app is this repo's KindredTable/.
- Working on two Macs: always `git pull` before editing, commit+push before switching.
