# LinguaCoach AI 🦜

A Duolingo-style **multi-language learning app for Android**, built with
**Flutter** and powered directly by the **Google Gemini API**. There is no
backend — every request goes straight from your device to Gemini.

---

## ✨ Features

Inside every language:

1. **AI Conversation Coach** — chat with a friendly tutor. After each message
   you get a corrected version, an explanation of mistakes (in your native
   language) and a more natural alternative.
2. **Speaking Practice** — the AI gives a task, you speak, and Gemini scores
   your transcript out of 10 with feedback. Correct pronunciation is played
   back with text-to-speech.
3. **Lessons** — AI-generated mini-lessons by topic with vocabulary, example
   sentences and translations.
4. **Exercises** — Gemini-generated quizzes in four formats: multiple choice,
   fill-in-the-blank, translate-the-sentence and listening. Strict JSON is
   parsed safely with automatic retries.
5. **Grammar Correction** — paste any text and get corrections with
   explanations.
6. **Daily Practice** — a word, a phrase and a speaking/writing challenge.
7. **Role-play Scenarios** — interview, restaurant, airport, shopping and more.

Plus:

- **Gamification** — XP, daily streak, levels, per-language progress and
  achievements, all saved locally.
- **Material 3** design with light/dark mode and a colourful Duolingo-like look.
- **Bottom navigation** — Home, Practice, Progress, Settings.
- **40+ languages** to learn and 16 native languages for explanations.

---

## 🔑 API key configuration

The app ships **with the API key already configured**, so there is no setup
screen on first launch. The key is not written in the source code; it is
injected at compile time from a repository secret:

```
flutter build apk --release --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"
```

In CI this comes from the **`GEMINI_API_KEY`** repository secret
(*Settings → Secrets and variables → Actions*). To rotate the key, update that
secret and re-run the workflow — nothing else changes.

The app also lets a user paste **their own** key in *Settings*; that personal
key takes priority over the built-in one and is stored with
`flutter_secure_storage`. Removing it falls back to the built-in key. In the UI
the key is always shown masked.

> **Note on security.** Anything embedded in a client app can be extracted from
> the APK. For production, put the key behind a small backend/proxy (or a
> Cloud Function) instead of shipping it in the app.

### Available models

Only models that currently respond are listed (verified against the live API):

| Model | Notes |
| --- | --- |
| `gemini-flash-latest` | **default** — always the newest Flash |
| `gemini-pro-latest` | most capable |
| `gemini-flash-lite-latest` | fastest / cheapest |
| `gemini-3.8-flash`, `gemini-3.7-flash`, `gemini-3.6-flash`, `gemini-3.5-flash` | pinned Flash versions |
| `gemini-3.1-flash-lite` | pinned Lite version |

Older names such as `gemini-2.5-flash` and `gemini-2.0-flash` now return
`404 … no longer available to new users`, which is why they are not offered.

---

## 🚀 Getting the APK (easiest way)

This repository builds the APK automatically with **GitHub Actions**.

1. Go to the **Actions** tab → **Build Android APK** → open the latest run.
2. Download the **`lingua-coach-apk`** artifact, **or**
3. Go to the **Releases** page and download `app-release.apk` from the latest
   release.

Then copy the APK to your phone and install it (you may need to allow
*Install unknown apps* for your file manager / browser).

---

## 🛠️ Building it yourself

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.24 or newer
- Android SDK (via Android Studio) and JDK 17

### Steps

```bash
# 1. Get the code
git clone https://github.com/shopshphereofficial-dev/LinguaCoach-AI.git
cd LinguaCoach-AI

# 2. Generate the Android platform folder (it is not committed, to keep the
#    repo free of binaries like gradle-wrapper.jar)
flutter create --platforms=android --org com.linguacoach --project-name lingua_coach_ai .
python3 .github/scripts/patch_android.py   # adds permissions + minSdk 21

# 3. Install packages
flutter pub get

# 4. Run on a connected device / emulator (pass your own key)
flutter run --dart-define=GEMINI_API_KEY="YOUR_KEY"

# 5. Build a release APK
flutter build apk --release --dart-define=GEMINI_API_KEY="YOUR_KEY"
# -> build/app/outputs/flutter-apk/app-release.apk
```

If you build **without** `--dart-define=GEMINI_API_KEY`, the app falls back to
a welcome screen that asks for a key — useful for development.

> The `patch_android.py` script adds the `INTERNET` and `RECORD_AUDIO`
> permissions, the speech-recognition/TTS `<queries>` entries needed on
> Android 11+, the app label and `minSdkVersion 21`.

---

## 📁 Project structure

```
lib/
├── main.dart                     # app entry + provider wiring
├── config/app_config.dart        # build-time API key / model
├── models/                       # Language, ChatMessage, QuizQuestion, Lesson,
│                                 # RolePlayScenario, UserProgress, Achievement
├── services/
│   ├── gemini_service.dart       # all Gemini REST calls + system prompts
│   ├── storage_service.dart      # secure key storage + preferences
│   └── speech_service.dart       # speech-to-text + text-to-speech
├── providers/
│   ├── settings_provider.dart    # API key, model, native language, theme
│   └── progress_provider.dart    # XP, streak, levels, achievements
├── screens/                      # 16 screens, one per feature + shell/tabs
├── widgets/                      # reusable UI pieces
└── theme/app_theme.dart          # Material 3 light/dark theme
```

---

## ⚠️ Notes

- All AI output is generated by Gemini and can occasionally be imperfect.
- The release APK from CI is signed with a debug key, which is fine for
  sideloading but **not** for the Play Store. Add your own signing config
  (`android/key.properties`) before publishing.
- Rate limits and errors are handled gracefully in the UI (invalid key, no
  internet, rate limit, blocked content).
