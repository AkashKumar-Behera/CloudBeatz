# 🎵 CloudBeatz

**CloudBeatz** is a customized and re-branded version of the open-source **Harmony-Music** project by [anandnet](https://github.com/anandnet/Harmony-Music).

This build focuses on improved UI design, rebranding (logo & name), and performance tweaks — made purely for **personal, educational, and non-commercial** use.

Hosted demo: 🌐 [https://cloudbeatz.web.app](https://cloudbeatz.web.app)

---

## 🚀 Features

- Stream music directly from YouTube / YouTube Music  
- Smart caching while playback  
- Radio and background playback support  
- Playlist creation & bookmarking  
- Artist and Album bookmark support  
- Import songs, playlists, albums, and artists via YouTube sharing  
- Adjustable streaming quality  
- Offline song downloading  
- Multi-language support  
- Skip silence feature  
- Dynamic theming system  
- Switch between Bottom and Side Navigation bar  
- Built-in Equalizer  
- Android Auto support  
- Synced & plain lyrics support  
- Sleep timer  
- No advertisements  
- No login required  
- Piped playlist integration  
- Real-time Collaborative Jam listening session support


---

## 🛠️ Prerequisites

Before you begin, make sure you have the following installed:
- **Flutter SDK** (Version `>=3.19.0`)
- **Dart SDK** (Bundled with Flutter)
- **Git** (for version control and submodules)

### Platform-specific requirements:
- **Android**: Android SDK & Android Studio (for compilation)
- **Windows**: Visual Studio with "Desktop development with C++" workload
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`

---

## 🧩 Technical Overview

CloudBeatz is a **cross-platform Flutter app** supporting **Android, Windows, and Linux**, designed for music playback, streaming, and playlist management.

Built with packages such as:
- `just_audio` – for core music playback  
- `media_kit` – for desktop audio support  
- `audio_service` – background audio management  
- `get` – for efficient state management  
- `youtube_explode_dart` – for streaming links  
- `hive` / `hive_flutter` – for local database storage  

### 🏛️ Architecture Details
- **State Management:** Powered by `GetX` for reactive state updates, easy dependency injection (`Get.put()`, `Get.find()`), and clean separation of UI from business logic.
- **Offline Storage:** Utilizing `Hive` boxes to store user preferences, search history, cached track info, and custom offline playlists efficiently with minimal overhead.
- **Audio Layer:** Integrates `just_audio` on mobile and `media_kit` on desktop through a unified background-capable `audio_service` implementation to guarantee a seamless listening experience.

### 🎨 Dynamic Theming & Customization
- **Dynamic Accent Colors:** Extract dominant colors from current album/song artwork to dynamically adjust the application theme and player background.
- **AMOLED Dark Mode:** Sleek dark mode design optimized for low-light environments and battery saving on OLED screens.
- **Adaptive Layouts:** Seamlessly adapts navigation patterns between a bottom navigation bar for mobile and a side navigation rail for desktop/tablet screens.

---

## 🚀 How to Run & Build

To get a local copy up and running, follow these steps:

### 1. Clone the Repository
```bash
git clone https://github.com/AkashKumar-Behera/CloudBeatz.git
cd CloudBeatz
```

### 2. Fetch Dependencies
```bash
flutter pub get
```

### 3. Run the App
Connect your device or start an emulator and run:
```bash
flutter run
```

### 4. Build for Production
* **Android (APK):** `flutter build apk --release`
* **Windows:** `flutter build windows --release`
* **Linux:** `flutter build linux --release`

### 5. Compile for iOS
To compile for iOS, please checkout the `ios` branch:
```bash
git checkout ios
```

---

## 📄 License

This project is derived from **Harmony-Music**, which is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

Under this license:
- You may **use, study, modify, and share** the code freely.  
- If you make your version public, you must **also share your modified source code** under the same GPL-3.0 license.  
- You **cannot sell or close-source** this app without explicit permission from the original author.

**Original project:**  
🔗 [Harmony-Music by anandnet](https://github.com/anandnet/Harmony-Music)

**Modified by:**  
👤 Akash Kumar Behera  
🌐 [https://cloudbeatz.web.app](https://cloudbeatz.web.app)  
📅 2025  

License:  
🧾 [GNU GPL-3.0 License](./LICENSE)

---

## ⚙️ Notes

- CloudBeatz is a **personal rebranded version** created for learning, testing, and showcasing UI/UX improvements.  
- It is **not affiliated with or endorsed by** the Harmony-Music project or its contributors.  
- All song, logo, and media rights belong to their respective owners.  
- This software is distributed “as-is” without any warranty or liability.

---

## ⚠️ Disclaimer

This project was created purely for **educational and experimental** purposes.  
CloudBeatz (and Harmony-Music) do **not host or own any audio content**.  
All media streamed or accessed through this app are property of their respective copyright holders.  

The author is **not responsible** for any copyright or intellectual property infringement resulting from misuse of this app.  
This software comes with **no warranties** and **no liabilities** of any kind.

---

## 🔍 Troubleshooting

Here are a few common issues and how to resolve them:
* **Audio doesn't play or buffers infinitely:** Check your internet connection. In some geographical regions, YouTube streaming endpoints might be throttled or blocked. Try connecting via a VPN.
* **Android build fails (Gradle errors):** Run `flutter clean` followed by `flutter pub get` to reset and clear the build cache.
* **Desktop audio issues:** Make sure your system's audio drivers are up to date and native library dependencies for `media_kit` are properly set up.

---

## 🗺️ Roadmap

Here are a few exciting features and enhancements planned for future updates:
- [ ] **Multi-threaded Downloads:** Improve the download manager to support speedier concurrent track downloading and pause/resume actions.
- [ ] **Third-party Playlist Imports:** Allow importing playlists from platforms like Spotify and Apple Music via text/URL parsing.
- [ ] **Widescreen UI Polish:** Further optimize the desktop UI for extremely wide monitors and multi-window layouts.
- [ ] **Local Metadata Support:** Improve offline playback by parsing ID3 and other tags from custom local folders.

---

## 🤝 Contributing

Contributions are welcome! Since this is a personal and educational repository, the focus is on maintaining high-quality UI/UX, fixing critical bugs, and improving audio performance.

If you want to contribute:
1. **Fork** the project
2. Create a new branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m "feat: add some AmazingFeature"`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a **Pull Request**

Please make sure your changes follow the rules in `analysis_options.yaml` and keep the GPL-3.0 licensing in mind.

---

## 📚 Learning References & Credits

This app was inspired by the amazing open-source community.  
Special thanks to:

- [Flutter documentation](https://docs.flutter.dev/) — cross-platform development reference  
- [Suragch](https://suragch.medium.com/) — audio and state management concepts  
- [sigma67](https://github.com/sigma67) — unofficial YouTube Music API  
- [vfsfitvnm](https://github.com/vfsfitvnm) — ViMusic (UI inspiration)  
- [LRCLIB](https://lrclib.net) — synced lyrics support  
- [Piped](https://piped.video) — for playlist integration  

---

© 2025 Akash Kumar Behera  
Released under the GNU General Public License v3.0 (GPL-3.0)
