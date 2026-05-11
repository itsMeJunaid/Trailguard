<div align="center">

# 🏔️ TrailGuard AI

### Your Offline AI Survival Companion for the Backcountry

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?logo=android)](https://developer.android.com)
[![AI](https://img.shields.io/badge/AI-Gemma%204%20(Offline)-FF6F00?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Kaggle](https://img.shields.io/badge/Kaggle-Hackathon-20BEFF?logo=kaggle)](https://kaggle.com)

**TrailGuard AI** is a fully offline AI-powered hiking and survival assistant built with Flutter.  
Powered by **Gemma 4** running on-device via Google's LiteRT-LM engine — no internet required, ever.

[Download APK](#-download--install-apk) · [Features](#-features) · [Getting Started](#-getting-started) · [Build from Source](#-build-from-source)

</div>

---

## 📖 Overview

When you're deep in the backcountry, signal disappears — but emergencies don't. **TrailGuard AI** puts a full survival expert, trail navigator, and emergency coordinator in your pocket, running entirely on your device without any internet connection.

- **Ask anything** about survival, first aid, plants, wildlife, or navigation
- **Analyze photos** of plants, injuries, or terrain using multimodal AI
- **Track your trail** with real-time GPS, distance, and elevation
- **Trigger SOS mode** for step-by-step emergency guidance
- **Use your voice** — speak questions and hear answers hands-free
- **Works offline** — once set up, zero connectivity needed

> **Hackathon Project** — Built for the Kaggle AI + Outdoor Safety Hackathon

---

## ✨ Features

| Feature | Description |
|---|---|
| 🤖 **Offline AI Chat** | Gemma 4 runs entirely on-device — no API keys, no data plan needed |
| 📸 **Image Analysis** | Photograph plants, insects, injuries, or terrain for AI identification |
| 🆘 **SOS Emergency Mode** | Structured first-aid trees for snake bites, bleeding, fractures, burns, and allergic reactions |
| 🗺️ **GPS Trail Tracking** | Log your route, distance, elevation, and checkpoints in real time |
| 🗾 **Offline Maps** | Cached OpenStreetMap tiles so you can navigate without signal |
| 🎙️ **Voice In / Out** | Speech-to-text input + text-to-speech responses, fully hands-free |
| 👤 **User Profile** | Store blood type, allergies, medications, and emergency contact for context-aware AI responses |
| 💬 **Chat History** | Multiple saved sessions stored locally in SQLite — review past guidance anytime |
| ⚡ **GPU Acceleration** | Optional OpenCL GPU backend for faster inference on supported devices |
| 📥 **In-App Model Download** | Download Gemma 4 directly inside the app — no manual file management |

---

## 📱 Download & Install APK

### Option A — Direct APK Install (Recommended for most users)

> **Note:** You do not need to build from source. Pre-built APKs are included in this repository.

#### Step 1 — Download the APK

| Variant | Size | Best For |
|---|---|---|
| [**app-arm64-v8a-release.apk**](build/app/outputs/flutter-apk/app-arm64-v8a-release.apk) | ~49 MB | **Most phones (2017+)** — Recommended |
| [app-armeabi-v7a-release.apk](build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk) | ~25 MB | Older 32-bit devices |
| [app-x86_64-release.apk](build/app/outputs/flutter-apk/app-x86_64-release.apk) | ~56 MB | Emulators / x86 tablets |

**Not sure which to use?** Pick `app-arm64-v8a-release.apk` — it works on virtually all modern Android phones (Samsung, Pixel, OnePlus, Xiaomi, etc.)

#### Step 2 — Enable Unknown Sources on your Android device

1. Open **Settings** on your phone
2. Go to **Security** (or **Privacy** on some devices)
3. Enable **"Install unknown apps"** or **"Unknown sources"**

On Android 8.0+, this is per-app:
1. Open your **Files** app or browser
2. When prompted, tap **"Allow from this source"**

> This is required for any APK not installed via the Google Play Store.

#### Step 3 — Transfer the APK to your phone

**Via USB cable:**
1. Connect your phone with a USB cable
2. Select **"File Transfer / MTP"** mode on your phone
3. Copy the APK file to your phone's `Downloads` folder

**Via cloud storage (alternative):**
- Upload the APK to Google Drive, Dropbox, or similar
- Open the link on your phone's browser and download it

**Via direct browser download:**
- If accessing this GitHub repo from your phone's browser, tap the APK link and download directly

#### Step 4 — Install the APK

1. Open your phone's **Files** app
2. Navigate to **Downloads**
3. Tap the **TrailGuard APK** file
4. Tap **"Install"** when prompted
5. If Google Play Protect warns you, tap **"Install anyway"** (the app is safe — it simply isn't Play Store verified)

#### Step 5 — Grant Permissions on first launch

TrailGuard will ask for these permissions — all are required for core features:

| Permission | Why It's Needed |
|---|---|
| **Location (GPS)** | Trail tracking and map positioning |
| **Camera** | Photo analysis via AI |
| **Microphone** | Voice input (speech-to-text) |
| **Storage** | Saving the AI model and chat history |
| **Notifications** | Background download progress |

Tap **"Allow"** or **"While using the app"** for each.

---

## 🚀 Getting Started (First Launch)

### 1. Complete Onboarding

When you first open TrailGuard, you'll go through a short setup:

1. **Welcome screen** — Overview of the app
2. **Profile setup** — Enter your name, age, blood type, allergies, medications, and emergency contact. This information is stored **only on your device** and used to personalize AI responses.
3. **Model download** — Choose and download a Gemma 4 model (see below)

### 2. Download the AI Model

TrailGuard requires a Gemma 4 model file to power the AI. You download it once and it lives on your device.

| Model | Size | Speed | Quality |
|---|---|---|---|
| **Gemma 4 E2B (Lite)** | ~1.5 GB | Faster | Good for most use cases |
| **Gemma 4 E4B (Full)** | ~2.8 GB | Slower | Best quality responses |

**How to download:**
1. On the model selection screen, tap your chosen model
2. Tap **"Download"** — this uses your internet connection (internet required for this step only)
3. Progress is shown with a percentage bar — download runs in the background
4. When complete, the model loads automatically

> **Tip:** Download over Wi-Fi. The model files are 1.5–2.8 GB.

> **Already have the model file?** Place it in your device's `/Downloads` or `/Documents` folder — TrailGuard will scan and detect it automatically on the storage scan screen.

### 3. Start Using the App

Once the model loads, you're ready. The bottom navigation has five sections:

| Tab | What It Does |
|---|---|
| 🏠 **Home** | Dashboard with quick actions, trail stats, and AI status |
| 💬 **Chat** | Main AI survival assistant — type or speak your questions |
| 🗺️ **Map** | GPS trail tracking and offline map view |
| 📸 **Camera** | Take photos for AI analysis |
| ⚙️ **Settings** | Profile, model settings, GPU toggle, notifications |

---

## 🤖 How to Use the AI Chat

1. Tap the **Chat** tab
2. Type your question or tap the **microphone** button to speak
3. The AI responds with streaming text — answers appear word by word
4. Tap the **speaker** icon to hear the response read aloud
5. To attach an image, tap the **📎 attachment** icon and select a photo

**Example questions to try:**
- *"I found a mushroom, is it safe to eat?"* (attach a photo)
- *"I twisted my ankle, what should I do?"*
- *"How do I build an emergency shelter with branches?"*
- *"What plants around me can I eat for hydration?"*
- *"The temperature is dropping fast, how do I stay warm?"*

---

## 🆘 How to Use SOS Emergency Mode

1. **Long-press** the red SOS button on the Home screen
2. Select your emergency type (injury, lost, medical, etc.)
3. Follow the step-by-step instructions from the AI Rescue Dispatcher
4. The AI uses your stored profile (blood type, allergies, medications) to give tailored guidance

> In a real emergency, always attempt to call **911** or local emergency services first if any signal is available. TrailGuard is a supplement, not a replacement for emergency services.

---

## 🗺️ How to Use Trail Tracking

1. Tap the **Map** tab
2. Tap **"Start Trail"** — the app begins logging your GPS position
3. Your path is drawn on the map in real time
4. Tap **"Add Marker"** to bookmark a checkpoint (e.g., campsite, water source)
5. Tap **"Pause"** to pause tracking (when resting)
6. Tap **"Stop Trail"** to end the session and save your route

Trail stats shown:
- Total distance (km/miles)
- Duration
- Current coordinates
- Elevation data

---

## 📸 How to Use Camera Analysis

1. Tap the **Camera** tab
2. Point at a plant, insect, injury, or terrain feature
3. Tap the shutter button to capture
4. Tap **"Analyze"** — the image is sent to the on-device Gemma 4 model
5. Read the AI's identification and advice in the result card below

---

## ⚙️ Settings & Configuration

| Setting | Description |
|---|---|
| **GPU Acceleration** | Toggle OpenCL GPU backend (faster on supported Snapdragon/Exynos chips) |
| **AI Model** | Switch between E2B (lite) and E4B (full) models |
| **Voice Speed** | Adjust text-to-speech playback speed |
| **Notifications** | Enable/disable background download notifications |
| **User Profile** | Update personal and medical information |
| **Storage Scan** | Manually scan for model files already on your device |

---

## 🔧 Build from Source

If you want to compile TrailGuard yourself:

### Prerequisites

- [Flutter 3.22+](https://docs.flutter.dev/get-started/install) installed and in your PATH
- [Android Studio](https://developer.android.com/studio) with Android SDK (API 21+)
- A connected Android device or emulator
- Git

Verify your setup:
```bash
flutter doctor
```
All entries should show a green checkmark.

### Clone & Run

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/trailguard-claude.git
cd trailguard-claude

# Install Flutter dependencies
flutter pub get

# Run in debug mode on a connected device
flutter run

# Or build a release APK
flutter build apk --split-per-abi --release
```

Built APKs will appear in:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk    # 64-bit ARM (most phones)
├── app-armeabi-v7a-release.apk  # 32-bit ARM (older phones)
└── app-x86_64-release.apk       # x86_64 (emulators)
```

### Run on Emulator

```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run
```

> **Note:** AI inference is CPU-only on emulators (no GPU). Responses will be slower than on a real device.

---

## 🧰 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.22 / Dart 3.3 |
| **AI Engine** | Gemma 4 via Google LiteRT-LM (on-device) |
| **State Management** | Flutter Riverpod 2.5 |
| **Navigation** | GoRouter 13.2 |
| **Database** | SQLite (sqflite) |
| **Maps** | flutter_map + OpenStreetMap |
| **GPS** | geolocator 12.0 |
| **Voice** | flutter_tts + speech_to_text |
| **Camera** | camera 0.11 + image_picker |
| **HTTP / Downloads** | dio + flutter_downloader |
| **Native Bridge** | Kotlin MethodChannel + EventChannel |

---

## 📋 Requirements

- **Android 5.0+** (API level 21 or higher)
- **1.5–2.8 GB free storage** for the AI model
- **RAM:** 4 GB minimum, 6 GB+ recommended for smooth inference
- **Internet:** Only required once to download the Gemma 4 model
- **GPS hardware** (present on all modern smartphones)

---

## 🛡️ Privacy

TrailGuard AI is built with privacy-first principles:

- **No data leaves your device** — all AI inference runs locally
- **No accounts or sign-up** required
- **No analytics or tracking** — zero telemetry
- **No API keys needed** — fully self-contained
- Profile data (medical info, emergency contact) is stored only in local SQLite

---

## 🤝 Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 🐛 Troubleshooting

**App crashes on launch:**
- Ensure you granted all permissions during onboarding
- Restart the app and try again

**AI model won't download:**
- Check your internet connection
- Ensure you have enough free storage (2–3 GB minimum)
- Try switching to a different Wi-Fi network

**AI responses are very slow:**
- Enable GPU acceleration in Settings (if your device supports it)
- Try switching to the lighter E2B model
- Close other apps to free up RAM

**GPS not tracking:**
- Ensure Location permission is set to "Always" or "While using app"
- Go outdoors or near a window — GPS requires sky visibility
- Check that Battery Saver mode isn't blocking background location

**Voice input not working:**
- Ensure Microphone permission is granted
- Check that your device volume is not muted
- Try restarting the app

**Google Play Protect blocks the install:**
- Tap **"More details"** → **"Install anyway"**
- The APK is safe but isn't signed through the Play Store

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ for hikers, adventurers, and anyone who ventures off the beaten path.

**Stay safe out there. TrailGuard has your back — even without a signal.**

</div>
