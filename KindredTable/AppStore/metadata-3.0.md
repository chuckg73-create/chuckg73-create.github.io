# KindredTable — App Store listing (first submission build)

Paste these into App Store Connect. Character limits noted; all fields are within limits.

---

## App Name  (<=30)
KindredTable

## Subtitle  (<=30)
Recipes matched to your taste

## Category
Primary: Food & Drink   Secondary: Lifestyle

## Promotional Text  (<=170 -- editable anytime without review)
Snap a photo of your fridge and get dinner ideas matched to your taste. Add a home screen widget for tonight's plan. Snap your finished dish for a personal food journal.

## Keywords  (<=100, comma-separated, no spaces after commas)
recipe,meal planner,fridge,pantry,cooking,dinner,grocery,cookbook,ingredients,what to cook,taste

## Description  (<=4000)
KindredTable turns what's already in your kitchen into meals you'll actually love -- matched to your taste, not a stranger's.

Snap a photo of your fridge or pantry and KindredTable identifies what you have, then suggests recipes built around it and tuned to how you like to eat. The more it learns about your taste, the better it gets.

WHAT MAKES IT DIFFERENT
- Taste-matched, not generic. Tell KindredTable the cuisines and flavors you love and the things you avoid, and every suggestion is scored to fit you personally.
- Your family cookbook. Photograph Mom's handwritten recipe cards or paste a link from any recipe site -- KindredTable reads them in, ingredients and steps and all, and keeps them beside the ideas it finds for you.
- Cook for exactly who's at the table. Scale any recipe up or down -- amounts and all -- for one, two, or a crowd.
- A personal food journal. After you cook, snap a photo of your dish. It lives on that recipe forever. Rate it and KindredTable learns your taste for next time.

EVERYTHING KINDREDTABLE DOES
- Fridge and pantry scan -- photograph what you have, edit the list, get meals you can make now
- Snap a single ingredient to find recipes built around it
- Taste-matched recipe ideas with a why-you'll-like-it note
- Home screen widget -- see tonight's planned dinner without opening the app
- Family Cookbook -- import recipes by photo or web link, saved forever
- Scale any recipe to any number of servings, instantly
- Per-serving nutrition -- calories, protein, carbs, fat
- Swap any ingredient in a tap -- get substitutions that respect your diet, or remove it entirely, with the steps rewritten to match
- Weekly meal planner -- drop recipes onto days, then turn the whole week into one aisle-sorted grocery list
- Cook by a time -- schedule reminders so every dish finishes together
- Cook Mode -- hands-free, step-by-step, with your screen kept awake
- Scan your kitchen equipment so recipe steps are written for the gear you own
- Cooking together -- blend your household's tastes so meals feel like everyone
- Daily dinner nudge at 5 pm, personalized to what's in your pantry
- Dietary rules honored -- vegetarian, vegan, gluten-free, allergens and more are strictly respected

Cook what you have. Cook what you love. KindredTable.

## What's New  (plain ASCII only -- no emoji, no em-dashes, no bullets with special chars)
First release.

KindredTable turns your fridge into dinner. Snap a photo of what you have, and get recipes matched to your taste -- with the family cookbook, meal planner, grocery list, and Cook Mode all in one place.

New in this release: home screen widget showing tonight's planned dinner, snap-to-identify a single ingredient, skeleton recipe previews while results load, and a daily 5 pm dinner nudge personalized to your pantry.

## URLs
Support URL:        https://chuckg73-create.github.io/kindredkitchen/support.html
Marketing URL:      https://chuckg73-create.github.io/kindredkitchen/
Privacy Policy URL: https://chuckg73-create.github.io/kindredkitchen/privacy.html

## Copyright
2026 Chuck Gallagher

## Age Rating
4+

## App Review notes (for the reviewer)
KindredTable identifies ingredients from a user-submitted photo and generates recipes via Google Gemini (proxied through a Cloudflare Worker -- no API key ships in the app). No account or login is required. All taste and profile data is stored on-device only.

To test: open the "On Hand" tab and add a few ingredients by hand (or use the camera icon to scan a fridge photo), then open the "Recipes" tab and tap "Find my dinner ideas." The app will generate 3 personalized recipe suggestions.

To test the widget: add a recipe to the Meal Plan tab for today, then add the KindredTable widget to the home screen -- it will show tonight's planned dinner.

The ingredient snap feature is on the "Crave" tab -- tap the camera icon next to the ingredient field to snap or choose a photo of a single ingredient.
