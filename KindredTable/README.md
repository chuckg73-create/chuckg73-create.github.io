# KindredKitchen

**Photograph your fridge. Cook what matches you.**

KindredKitchen is a native SwiftUI app for iOS. Snap a photo of your fridge or
pantry and the app identifies the ingredients **on-device** with Apple's Vision
framework — no image ever leaves your phone. It then generates daily meal
suggestions from what you have on hand, personalised to your taste profile and
kitchen equipment, using a Gemini LLM call for the recipe matching (the same
integration pattern as the KindredCompass recommendation flow).

> The Xcode target, bundle id, and folders are still named `KindredTable`; the
> app's display name is **KindredKitchen**.

## Features

- **Capture screen** — take a photo (or pick one from the library) and get
  ingredients recognised locally via `VNClassifyImageRequest`.
- **On Hand (editable ingredient list)** — grouped by category, with add / edit /
  swipe-to-delete and search. Typing an ingredient offers **type-ahead
  suggestions** and **auto-files it into the right category** (produce, protein,
  dairy, grain, spice, frozen, …). Correct anything the recogniser misses.
- **Recipe feed** — daily meal ideas ranked by how well they fit your pantry,
  taste, and equipment, each with a match score, cook time, and "why you'll like
  it" note.
- **Save for later** — bookmark recipes; saved items persist locally.
- **Grocery list** — add items by hand (auto-categorised) or pull a recipe's
  "need to buy" items in one tap. Check items off, then **move what you bought
  into On Hand**. A **"Shop this list"** button hands the list off to Instacart
  or Walmart (copies the list + opens the store), plus a share/export option.
- **Taste profile** — diets, loved cuisines, disliked ingredients, allergens,
  spice level, skill, max cook time, and **kitchen equipment** (air fryer,
  pellet smoker, sous vide, griddle, espresso machine, …) drive the
  personalisation.

## Architecture

```
KindredTable/
├─ App/            App entry, root tab + onboarding routing
├─ Models/         Ingredient, Recipe, TasteProfile, GroceryItem (Codable value types)
├─ Services/       VisionIngredientRecognizer (on-device), GeminiRecipeService (LLM),
│                  FoodVocabulary (match/categorise/suggest), AppConfig, SampleData
├─ Stores/         @Observable stores: Pantry, SavedRecipes, Profile, Grocery, RecipeFeed
├─ Theme/          KindredTheme design tokens (KindredCompass brand palette)
├─ Views/          Capture, Pantry, Recipes, Grocery, Profile, shared Components
└─ Resources/      Asset catalog, preview content
```

- **On-device Vision** — `VisionIngredientRecognizer` runs Vision's built-in
  image classifier, filters results against a curated `FoodVocabulary`, and maps
  labels to categorised `Ingredient`s. No bundled Core ML model, fully offline.
- **Smart categorisation** — `FoodVocabulary` maps free text to a grocery
  category using vocabulary + word matching (most-specific wins) plus keyword
  heuristics, and powers type-ahead suggestions.
- **LLM recipe matching** — `GeminiRecipeService` builds a prompt from the
  pantry, taste profile, and equipment, POSTs it to Gemini's `generateContent`
  endpoint (`gemini-2.5-flash`, thinking disabled, JSON response) with
  `URLSession`, and decodes it into `Recipe`s. Only ingredient names and
  preferences are sent — never personal identifiers.
- **Local-first storage** — pantry, saved recipes, grocery list, and profile are
  persisted as JSON in the app's Documents directory via `LocalStore`.

## Setup

Requirements: **Xcode 16+**, **iOS 17+**.

1. Open `KindredTable/KindredTable.xcodeproj`.
2. Select the `KindredTable` scheme and run on a device or simulator.
   (Ingredient recognition works on the simulator via the photo library; the
   live camera needs a real device.)

### Adding a Gemini API key

Without a key the app runs in an offline **sample mode** so every screen is
explorable. To enable real, pantry-tailored suggestions — in **one step**:

```bash
cd KindredTable
cp Secrets.example.xcconfig Secrets.xcconfig
# edit Secrets.xcconfig →  GEMINI_API_KEY = AIza...your key...
```

That's it — build and run. No Xcode Configurations wiring required: the project's
base config (`Config.xcconfig`, committed) already does `#include? "Secrets.xcconfig"`,
so your key flows `Secrets.xcconfig → GEMINI_API_KEY → Info.plist →
AppConfig.geminiAPIKey`. This works in Simulator, device, and TestFlight builds
alike. `Secrets.xcconfig` is gitignored, so the key is never committed.

Get a key from [Google AI Studio](https://aistudio.google.com/app/apikey) — it
starts with `AIza`.

> **Security:** this bakes the key into the app binary, which is fine for personal
> and TestFlight builds but extractable by others. For a public App Store release,
> proxy Gemini through a small backend instead of shipping the key.

## Grocery ordering

The **"Shop this list"** button is a handoff: it copies your list and opens
Instacart or Walmart so you can paste-search and check out there. True one-tap
in-app ordering would require **partner API access** (Instacart Developer
Platform / Connect, or Walmart's affiliate/marketplace APIs) plus a backend to
hold credentials — that path can be added once partner access is granted.

## Privacy

Photos are analysed entirely on-device and are never uploaded. Your taste
profile, pantry, grocery list, and saved recipes stay on your device. Only
ingredient names and taste preferences are sent to the recipe-matching model to
generate suggestions.
