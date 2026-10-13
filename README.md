# LinguaCoach AI 🦜

A Duolingo-style **multi-language learning app for Android**, built with
**Flutter** and powered directly by the **Google Gemini API**. There is no
backend — every request goes straight from your device to Gemini using your own
API key.

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
- **Your own API key** — entered on first launch, stored with
  `flutter_secure_storage`, validated with a test call, and changeable in
  Settings.

---

## 🚀 Getting the APK (easiest way)

This repository builds the APK automatically with **GitHub Actions**.

1. Go to the **Actions** tab → **Build Android APK** → open the latest run.
2. Download the **`lingua-coach-apk`** artifact, **or**
3. Go to the **Releases** page and download `app-release.apk` from
   **LinguaCoach AI v1.0.0**.

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

# 4. Run on a connected device / emulator
flutter run

# 5. Build a release APK
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

> The `patch_android.py` script adds the `INTERNET` and `RECORD_AUDIO`
> permissions, the speech-recognition/TTS `<queries>` entries needed on
> Android 11+, the app label and `minSdkVersion 21`.

---

## 🔑 Getting a Gemini API key

1. Open **Google AI Studio** — <https://aistudio.google.com>.
2. Sign in and click **Get API key**.
3. Create a key and paste it into the app's welcome screen.

The default model is **`gemini-2.5-flash`**; you can switch to
`gemini-2.5-pro`, `gemini-2.5-flash-lite` or `gemini-2.0-flash` in Settings.

Your key is stored **only on your device** and is never committed or sent
anywhere except Google's API.

---

## 📁 Project structure

```
lib/
├── main.dart                     # app entry + provider wiring
├── models/                       # Language, ChatMessage, QuizQuestion, Lesson,
│                                 # RolePlayScenario, UserProgress, Achievement
├── services/
│   ├── gemini_service.dart       # all Gemini REST calls + system prompts
│   ├── storage_service.dart      # secure key storage + preferences
│   └── speech_service.dart       # speech-to-text + text-to-speech
├── providers/
│   ├── settings_provider.dart    # API key, model, native language, theme
│   └── progress_provider.dart    # XP, streak, levels, achievements
├── screens/
│   ├── api_key_screen.dart       # first-launch onboarding
│   ├── home_shell.dart           # bottom navigation
│   ├── home_tab.dart             # language grid
│   ├── language_detail_screen.dart
│   ├── conversation_screen.dart  # 1. AI Conversation Coach
│   ├── speaking_screen.dart      # 2. Speaking Practice
│   ├── lessons_screen.dart       # 3. Lessons
│   ├── lesson_detail_screen.dart
│   ├── exercises_screen.dart     # 4. Exercises
│   ├── grammar_screen.dart       # 5. Grammar Correction
│   ├── daily_practice_screen.dart# 6. Daily Practice
│   ├── roleplay_screen.dart      # 7. Role-play
│   ├── roleplay_chat_screen.dart
│   ├── practice_tab.dart
│   ├── progress_screen.dart
│   └── settings_screen.dart
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
