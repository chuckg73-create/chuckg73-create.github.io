# KindredTable

**Photograph your fridge. Cook what matches you.**

KindredTable is a native SwiftUI app for iOS. Snap a photo of your fridge or
pantry and the app identifies the ingredients **on-device** with Apple's Vision
framework — no image ever leaves your phone. It then generates daily meal
suggestions from what you have on hand, personalised to your taste profile, using
a Gemini LLM call for the recipe matching (the same integration pattern as the
KindredCompass recommendation flow).

## Features

- **Capture screen** — take a photo (or pick one from the library) and get
  ingredients recognised locally via `VNClassifyImageRequest`.
- **Editable ingredient list (Pantry)** — grouped by category, with add / edit /
  swipe-to-delete and search. Correct anything the recogniser misses.
- **Recipe feed** — daily meal ideas ranked by how well they fit your pantry and
  taste, each with a match score, cook time, and "why you'll like it" note.
- **Save for later** — bookmark recipes; saved items persist locally.
- **Taste profile** — diets, loved cuisines, disliked ingredients, allergens,
  spice level, skill, and max cook time drive the personalisation.

## Architecture

```
KindredTable/
├─ App/            App entry, root tab + onboarding routing
├─ Models/         Ingredient, Recipe, TasteProfile (Codable value types)
├─ Services/       VisionIngredientRecognizer (on-device), GeminiRecipeService (LLM),
│                  FoodVocabulary, AppConfig, SampleData (offline fallback)
├─ Stores/         @Observable stores: Pantry, SavedRecipes, Profile, RecipeFeed
├─ Theme/          KindredTheme design tokens (KindredCompass brand palette)
├─ Views/          Capture, Pantry, Recipes, Profile, shared Components
└─ Resources/      Asset catalog, preview content
```

- **On-device Vision** — `VisionIngredientRecognizer` runs Vision's built-in
  image classifier, filters results against a curated `FoodVocabulary`, and maps
  labels to categorised `Ingredient`s. No bundled Core ML model, fully offline.
- **LLM recipe matching** — `GeminiRecipeService` builds a prompt from the pantry
  and taste profile, POSTs it to Gemini's `generateContent` endpoint with
  `URLSession`, requests strict JSON, and decodes it into `Recipe`s. Only
  ingredient names and preferences are sent — never personal identifiers.
- **Local-first storage** — pantry, saved recipes, and profile are persisted as
  JSON in the app's Documents directory via `LocalStore`.

## Setup

Requirements: **Xcode 16+**, **iOS 17+**.

1. Open `KindredTable/KindredTable.xcodeproj`.
2. Select the `KindredTable` scheme and run on a device or simulator.
   (Ingredient recognition works on the simulator via the photo library; the
   live camera needs a real device.)

### Adding a Gemini API key

Without a key the app runs in an offline **sample mode** so every screen is
explorable. To enable real, pantry-tailored suggestions:

1. Copy `Secrets.example.xcconfig` to `Secrets.xcconfig` (already gitignored).
2. Paste your [Gemini API key](https://aistudio.google.com/app/apikey) into it.
3. In **Project ▸ Info ▸ Configurations**, set the base configuration for Debug
   and Release to `Secrets.xcconfig`.

The key flows `Secrets.xcconfig → GEMINI_API_KEY → INFOPLIST_KEY_GEMINI_API_KEY →
Info.plist → AppConfig.geminiAPIKey`. You can also set a `GEMINI_API_KEY`
environment variable in the scheme for quick local testing.

## Privacy

Photos are analysed entirely on-device and are never uploaded. Your taste
profile, pantry, and saved recipes stay on your device. Only ingredient names and
taste preferences are sent to the recipe-matching model to generate suggestions.
