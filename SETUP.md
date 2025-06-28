# Car Wash App Setup Guide

## Environment Configuration

### 1. Environment Variables
Copy the template environment file and configure it with your actual values:

```bash
cp assets/.env.template assets/.env
```

Edit `assets/.env` with your actual configuration:

```env
# API Configuration
BASE_URL=https://your-actual-api-domain.com

# Firebase Configuration
FIREBASE_API_KEY_ANDROID=your_actual_firebase_api_key_android
FIREBASE_API_KEY_IOS=your_actual_firebase_api_key_ios
FIREBASE_PROJECT_ID=your_actual_firebase_project_id
FIREBASE_STORAGE_BUCKET=your_actual_firebase_storage_bucket
FIREBASE_MESSAGING_SENDER_ID=your_actual_firebase_messaging_sender_id
```

### 2. Firebase Configuration

#### Android
Copy the template and configure it with your Firebase project settings:

```bash
cp android/app/google-services.json.template android/app/google-services.json
```

Edit `android/app/google-services.json` with your actual Firebase configuration.

#### iOS
Copy the template and configure it with your Firebase project settings:

```bash
cp ios/Runner/GoogleService-Info.plist.template ios/Runner/GoogleService-Info.plist
```

Edit `ios/Runner/GoogleService-Info.plist` with your actual Firebase configuration.

## Security Notes

- Never commit the actual `.env` file or Firebase configuration files
- These files are already added to `.gitignore`
- Only template files should be committed to the repository
- Keep your API keys and secrets secure

## Getting Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings
4. Download the configuration files for Android and iOS
5. Replace the template files with the downloaded ones 