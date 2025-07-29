# Telegram Bot Hosting App

A mobile app for hosting Telegram Python bots using free-tier tools.

## Setup

### Backend (Railway)
1. Push code to a GitHub repo.
2. Sign up at `railway.app`, create a new project, and link your repo.
3. Add environment variable: `FIREBASE_CREDENTIALS` (Firebase Admin SDK JSON).
4. Deploy the backend service (uses `Dockerfile`).
5. Note the public URL (e.g., `https://your-railway-url`).

### Frontend (Flutter)
1. Install Flutter SDK: `flutter.dev`.
2. Run `flutter pub get` in `frontend/`.
3. Build APK: `flutter build apk`.
4. Test on emulator or device.
5. Optionally host APK on Firebase Hosting.

### Firebase
1. Create a Firebase project at `console.firebase.google.com`.
2. Enable Authentication (Google, Email/Password).
3. Add Firebase SDK to Flutter (`pubspec.yaml`).
4. Download Admin SDK JSON for backend (`FIREBASE_CREDENTIALS`).

### AdMob
1. Create an AdMob account at `admob.google.com`.
2. Get a rewarded ad unit ID.
3. Update `frontend/lib/screens/deploy_screen.dart` with your ad unit ID.

## Notes
- Replace `your-railway-url` in `api_service.dart` with your Railway URL.
- Replace `your-bot-id` in `logs_screen.dart` and `stats_screen.dart` with dynamic bot ID from `DeployScreen`.
- Ensure `bots/` directory has write permissions on Railway.