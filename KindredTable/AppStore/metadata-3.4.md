# KindredTable -- App Store listing v3.4

Paste these into App Store Connect. Character limits noted; all fields are within limits.

---

## App Name  (<=30, 13 chars)
KindredTable

## Subtitle  (<=30, 29 chars)
Recipes matched to your taste

## Category
Primary: Food & Drink   Secondary: Lifestyle

## Promotional Text  (<=170 -- editable anytime without review, 168 chars)
Cook Mode now lives on your Lock Screen and Dynamic Island. Plus technique guides, baker's ratios, family taste blending, and recipes imported from any site on the web.

## Keywords  (<=100, comma-separated)
recipe,meal planner,cooking,dinner,fridge,pantry,cookbook,ingredients,technique,baker,grocery,taste

## Description  (<=4000)
KindredTable turns what's already in your kitchen into meals you'll actually love -- matched to your taste, not a stranger's.

Snap a photo of your fridge or pantry and KindredTable identifies what you have, then suggests recipes built around it and tuned to how you like to eat. The more it learns about your taste, the better it gets.

WHAT MAKES IT DIFFERENT
- Taste-matched, not generic. Tell KindredTable the cuisines and flavors you love and the things you avoid, and every suggestion is scored to fit you personally.
- Cook for exactly who's at the table. Add family members by QR code and KindredTable blends everyone's taste -- never suggesting something someone dislikes or is allergic to.
- Your family cookbook. Photograph Mom's handwritten recipe cards or paste a link from any recipe site -- KindredTable reads them in, ingredients and steps and all.
- A personal food journal. After you cook, snap a photo of your dish. Rate it and KindredTable learns your taste for next time.
- Technique guides built in. 36 step-by-step cooking guides -- from filleting a fish to making a roux -- each with a curated video link.

EVERYTHING KINDREDTABLE DOES
- Fridge and pantry scan -- photograph what you have, edit the list, get meals you can make right now
- Taste-matched recipe ideas with a why-you'll-like-it note
- Import any recipe from the web -- paste a URL from NYT Cooking, Serious Eats, AllRecipes, or anywhere
- Baker's percentages -- scale a baking recipe to any size while keeping the ratios right
- Cook Mode with Live Activities -- your current step and timers on the Dynamic Island and Lock Screen
- Multiple named timers running simultaneously in Cook Mode
- Visual cook timeline -- back-time any dinner at a glance
- In-cook substitutions -- ask for a swap mid-recipe without leaving Cook Mode
- Technique guides -- 36 built-in cooking guides with video links, surfaced automatically in Cook Mode
- Family taste blending -- share your taste by QR code, blend everyone's preferences
- Scale any recipe to any number of servings, instantly
- Per-serving nutrition -- calories, protein, carbs, fat
- Swap any ingredient with AI rewritten steps to match
- Weekly meal planner -- drop recipes onto days, turn the week into one aisle-sorted grocery list
- Cook by a time -- schedule reminders so every dish finishes together
- Scan your kitchen equipment so recipe steps are written for what you own
- Home screen widget -- see tonight's planned dinner without opening the app
- Daily dinner nudge at 5 pm, personalized to your pantry
- Dietary rules honored -- vegetarian, vegan, gluten-free, allergens and more strictly respected

Cook what you have. Cook what you love. KindredTable.

## What's New  (plain ASCII only -- no emoji, no em-dashes, no special bullet chars)
KindredTable 3.4 is the biggest update yet.

COOK MODE ON YOUR LOCK SCREEN
Your current step and any running timer now live on the Dynamic Island and Lock Screen while you cook. Glance at your phone without unlocking it and stay right where you left off.

TECHNIQUE GUIDES
36 built-in cooking guides -- how to fillet a fish, soft-boil eggs, make a roux, deglaze a pan, julienne vegetables, and more. Each guide opens a step-by-step walkthrough with pro tips and a link to a video tutorial. Cook Mode surfaces them automatically when it detects a technique in your current step.

BAKER'S PERCENTAGES
Scale a baking recipe to any size and KindredTable now shows every ingredient as a percentage of flour so your ratios stay right no matter what batch size you choose.

VISUAL COOK TIMELINE
The Cook Plan screen now shows a Gantt-style timeline with a live Now marker. Back-timing dinner is a glance, not a calculation.

IMPORT RECIPES FROM THE WEB
Paste a URL from NYT Cooking, Serious Eats, AllRecipes, or anywhere and KindredTable extracts the recipe straight into your cookbook.

MULTIPLE TIMERS AT ONCE
Name each timer for what it is timing -- wings, sauce, rice -- and run them all simultaneously. Each one can be paused or dismissed individually without leaving Cook Mode.

FAMILY TASTE BLENDING
Add family members by QR code and KindredTable blends everyone's taste into every suggestion. It never recommends something someone at the table dislikes or is allergic to.

MORE IN THIS UPDATE
- Save a photo of your finished dish right after you cook it
- Ask for an ingredient substitute mid-recipe without leaving Cook Mode
- Add your name and a profile photo
- Craving search is now inline on the home screen

## URLs
Support URL:        https://chuckg73-create.github.io/kindredkitchen/support.html
Marketing URL:      https://chuckg73-create.github.io/kindredkitchen/
Privacy Policy URL: https://chuckg73-create.github.io/kindredkitchen/privacy.html

## Copyright
2026 Chuck Gallagher

## Age Rating
4+

## App Review Notes (for the Apple reviewer -- paste into the Notes field)
KindredTable generates recipe suggestions and cooking guidance via Google Gemini, proxied through a Cloudflare Worker. No API key ships in the app. No account or login is required. All taste and profile data is stored on-device only.

TO TEST THE CORE FLOW
1. Open the Pantry tab and add a few ingredients by hand (or tap the camera icon to scan a fridge photo).
2. Open the Recipes tab -- the app will generate personalized recipe suggestions.
3. Tap any recipe to see the detail view, then tap "Cook" to enter Cook Mode.

TO TEST LIVE ACTIVITIES (Dynamic Island / Lock Screen)
1. Enter Cook Mode on any recipe.
2. The current step and any running timer will appear on the Lock Screen and in the Dynamic Island on supported devices.
3. Live Activities require iOS 16.2 or later and must be enabled in Settings > [App Name] > Live Activities.

TO TEST TECHNIQUE GUIDES
1. Open the Cookbook tab and tap "Technique guides."
2. Browse the 36 preset guides by category, or type any technique name for an AI-generated guide.

TO TEST URL IMPORT
1. Open the Cookbook tab, tap the three-dot menu in the top right, and choose "Import from URL."
2. Paste any recipe URL (e.g. from seriouseats.com or allrecipes.com) and tap Import.

TO TEST FAMILY TASTE BLENDING
1. Open the Profile tab and tap "Cooking for."
2. Tap "Share my taste" to generate a QR code. Scan it with a second device to add a household member.

The app does not make purchases, access contacts, use location, or communicate with any server other than the Cloudflare Worker proxy for Gemini requests.
