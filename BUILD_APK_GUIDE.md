# CloudBeatz APK Build Guide 🚀

Ye document CloudBeatz application ke release APK builds banane ke commands aur details provide karta hai.

---

## 1. Standard Release APK (Recommended for General Use)
Ek single universal APK banti hai jo sabhi Android CPU architectures (arm64, armeabi-v7a, x86_64) par chalegi.

```powershell
flutter build apk --release
```

- 📍 **Output Path:** `build\app\outputs\flutter-apk\app-release.apk`

---

## 2. Split Per-ABI Release APKs (Optimized / Smaller Size)
Alag-alag CPU architecture ke hisab se separate APKs banti hain. Isse APK ka file size kafi chhota ho jata hai.

```powershell
flutter build apk --release --split-per-abi
```

- 📍 **Output Paths:**
  - `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` *(Modern phones ke liye - Sabse common)*
  - `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` *(Older 32-bit phones)*
  - `build\app\outputs\flutter-apk\app-x86_64-release.apk` *(Emulators / Chromebooks)*

---

## 3. Production / Secure Obfuscated APK (Code Protection)
Source code ko reverse-engineering / decompiling se bachane ke liye code ko scramble (obfuscate) karta hai aur debugging symbols ko alag folder me save karta hai.

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

- 📍 **APK Output:** `build\app\outputs\flutter-apk\app-release.apk`
- 📍 **Symbols Output:** `build\symbols\`

---

## 4. Skip Build Dependency Validation Warning
Agar build karte waqt Gradle/AGP version warning aati hai aur fast build chahiye, to ye flag pass karein:

```powershell
flutter build apk --release --android-skip-build-dependency-validation
```

---

## 5. Clean Build (Troubleshooting)
Agar purane cache ya build artifacts se koi error aaye to pehle clean karein:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```
