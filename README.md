# LinguaCoach AI 🎓

A Duolingo-style **multi-language learning app for Android**, built with
**Flutter** and powered directly by the **Google Gemini API**. There is no
backend — every request goes straight from your device to Gemini.

**New in v1.2.0 — real-time live classes.** Instead of tapping a mic and waiting,
you now hold a genuine live voice conversation with an animated AI teacher who
answers instantly, can be interrupted, and lip-syncs to their own voice.

---

## 🎓 Live classes with animated teachers

The headline feature is a **Live API** voice session (WebSocket, streaming audio
both ways) with one of five teachers. Each teacher has a name, a personality, a
Gemini voice and a hand-drawn animated avatar.

| Teacher | Style | Languages | Voice |
| --- | --- | --- | --- |
| **Aanya** | Warm & encouraging | Hindi · English | Aoede |
| **Marco** | Energetic & fun | Spanish · Italian | Puck |
| **Yuki** | Calm & precise | Japanese · Korean | Kore |
| **Layla** | Friendly & expressive | Arabic · French | Leda |
| **Sofia** | Cheerful & clear | Portuguese · German | Zephyr |

Pick your teacher on the Home tab (the "Your teachers" strip) or in Settings.

**What makes it live**

- Audio is streamed continuously, so the teacher hears you *as you speak* — no
  push-to-talk, no send button, no waiting for a reply to be generated.
- The teacher starts talking within a fraction of a second and **you can barge
  in** at any time; their queued audio is dropped immediately.
- Live captions show both sides of the conversation as it happens.

**The avatar** is painted entirely in code (`TeacherAvatar`), so it needs no
image assets and stays sharp at any size. It reacts to the live audio:

- **Lip sync** — the mouth opening is driven by the loudness of the teacher's
  voice, frame by frame.
- **Eye blinking** — natural random blinks, with the occasional double blink.
- **Hair & idle motion** — the hair sways, the head bobs and tilts, and the
  whole figure breathes gently so it never looks frozen.
- **Expression** — eyebrows lift while speaking, blush appears during speech, and
  the pose changes between listening and talking.

---

## ✨ Everything else

Inside every language:

1. **AI Conversation Coach** — chat with a tutor. After each message you get a
   corrected version, an explanation (in your native language) and a more
   natural alternative.
2. **Speaking Practice** — the AI gives a task, you speak, and Gemini scores your
   transcript out of 10 with feedback.
3. **Lessons** — AI-generated mini-lessons by topic with vocabulary and examples.
4. **Exercises** — quizzes in four formats: multiple choice, fill-in-the-blank,
   translate-the-sentence and listening. Strict JSON is parsed with retries.
5. **Grammar Correction** — paste any text and get corrections with explanations.
6. **Daily Practice** — a word, a phrase and a speaking/writing challenge.
7. **Role-play Scenarios** — interview, restaurant, airport, shopping and more.

Plus gamification (XP, streak, levels, per-language progress, achievements),
Material 3 light/dark, bottom navigation, 40+ languages and 16 native languages.

---

## 🔑 API key configuration

The app ships **with the API key already configured**, so there is no setup
screen. The key is not written in the source code; it is injected at compile
time from a repository secret:

```
flutter build apk --release --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY"
```

In CI this comes from the **`GEMINI_API_KEY`** repository secret
(*Settings → Secrets and variables → Actions*). To rotate the key, update that
secret and re-run the workflow — nothing else changes.

A user can still paste **their own** key in *Settings*; it takes priority over
the built-in one and is stored with `flutter_secure_storage`. The key is always
shown masked in the UI.

> **Security note.** Anything embedded in a client app can be extracted from the
> APK. For production, put the key behind a backend/proxy (or use ephemeral
> tokens, which the Live API supports) instead of shipping it in the app.

### Models

Only models that currently respond are offered (verified against the live API):

**Live voice (real-time):** `gemini-3.8-live` (default),
`gemini-3.1-flash-live-preview`, `gemini-2.5-flash-native-audio-latest`.

**Text:** `gemini-flash-latest` (default), `gemini-pro-latest`,
`gemini-flash-lite-latest`, `gemini-3.8/3.7/3.6/3.5-flash`,
`gemini-3.1-flash-lite`.

Older names such as `gemini-2.5-flash` and `gemini-2.0-flash` now return
`404 … no longer available to new users`.

---

## 🚀 Getting the APK

1. **Actions** tab → **Build Android APK** → download the `lingua-coach-apk`
   artifact, **or**
2. the **Releases** page → download `app-release.apk`.

Install it on your Android device (allow *Install unknown apps* if asked).

---

## 🛠️ Building it yourself

```bash
git clone https://github.com/shopshphereofficial-dev/LinguaCoach-AI.git
cd LinguaCoach-AI

flutter create --platforms=android --org com.linguacoach --project-name lingua_coach_ai .
python3 .github/scripts/patch_android.py    # permissions, minSdk 21, icons

flutter pub get
flutter run --dart-define=GEMINI_API_KEY="YOUR_KEY"
flutter build apk --release --dart-define=GEMINI_API_KEY="YOUR_KEY"
```

Requires Flutter 3.24+ and JDK 17. Without the `--dart-define` the app falls
back to a welcome screen asking for a key.

---

## 📁 Project structure

```
lib/
├── main.dart                     # app entry + provider wiring
├── config/app_config.dart        # build-time API key / model
├── models/                       # Language, Teacher, ChatMessage, QuizQuestion,
│                                 # Lesson, RolePlayScenario, UserProgress, …
├── services/
│   ├── gemini_service.dart       # text REST calls + system prompts
│   ├── live_session_service.dart # Gemini Live API over WebSocket (voice)
│   ├── audio_io_service.dart     # 16 kHz mic capture + 24 kHz PCM playback
│   ├── storage_service.dart      # secure key storage + preferences
│   └── speech_service.dart       # speech-to-text + text-to-speech
├── providers/                    # settings + progress
├── screens/                      # 17 screens (incl. live_class_screen)
├── widgets/
│   ├── teacher_avatar.dart       # animated, lip-syncing avatar (CustomPainter)
│   ├── app_logo.dart             # logo mark, drawn in code
│   └── common.dart               # shared UI pieces
└── theme/app_theme.dart
```

---

## ⚠️ Notes

- The Live API needs a real device or an emulator with a working microphone.
- All AI output is generated by Gemini and can occasionally be imperfect.
- The CI APK is debug-signed: fine for sideloading, **not** for the Play Store.
- Errors (invalid key, no internet, rate limit, blocked content) are handled
  gracefully in the UI.
