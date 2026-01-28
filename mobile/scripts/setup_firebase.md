# Firebase Setup Guide for Money Guardian

This guide walks you through setting up Firebase for push notifications.

## Prerequisites
- A Google account
- Access to [Firebase Console](https://console.firebase.google.com)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name: `Money Guardian`
4. Enable/disable Google Analytics as needed
5. Click "Create project"

## Step 2: Add Android App

1. In Firebase Console, click the Android icon to add an Android app
2. Enter the following details:
   - **Package name**: `com.moneyguardian.app`
   - **App nickname**: Money Guardian Android
   - **Debug signing certificate SHA-1**: (optional for development)
3. Click "Register app"
4. Download `google-services.json`
5. Move the file to: `mobile/android/app/google-services.json`

## Step 3: Add iOS App

1. In Firebase Console, click "Add app" and select iOS
2. Enter the following details:
   - **Bundle ID**: `com.moneyguardian.app`
   - **App nickname**: Money Guardian iOS
   - **App Store ID**: (leave empty for now)
3. Click "Register app"
4. Download `GoogleService-Info.plist`
5. Move the file to: `mobile/ios/Runner/GoogleService-Info.plist`

**Important for iOS**: You also need to add the file to Xcode:
1. Open `mobile/ios/Runner.xcworkspace` in Xcode
2. Right-click on `Runner` folder
3. Select "Add Files to Runner..."
4. Select `GoogleService-Info.plist`
5. Ensure "Copy items if needed" is checked
6. Click "Add"

## Step 4: Enable Cloud Messaging

1. In Firebase Console, go to "Cloud Messaging" (under Engage)
2. For iOS, you need to upload APNs authentication key:
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Navigate to Certificates, Identifiers & Profiles > Keys
   - Create a new key with "Apple Push Notifications service (APNs)" enabled
   - Download the `.p8` file
   - In Firebase Console > Project Settings > Cloud Messaging
   - Under "Apple app configuration", upload the APNs key

## Step 5: Verify Setup

After adding the config files, run:

```bash
cd mobile

# For iOS
cd ios && pod install && cd ..

# Build and run
flutter run
```

## File Locations

```
mobile/
├── android/
│   └── app/
│       └── google-services.json    <-- Android config (from Step 2)
└── ios/
    └── Runner/
        └── GoogleService-Info.plist <-- iOS config (from Step 3)
```

## Troubleshooting

### "GoogleService-Info.plist not found"
- Ensure the file is in `ios/Runner/` directory
- Ensure the file is added to Xcode project

### "Default FirebaseApp is not configured"
- Ensure `FirebaseApp.configure()` is called in AppDelegate.swift (already done)
- Ensure config files are in correct locations

### "No APNs token"
- iOS simulators don't support push notifications
- Test on a real device
- Ensure APNs key is uploaded to Firebase Console

## Testing Push Notifications

### Using Firebase Console
1. Go to Firebase Console > Cloud Messaging
2. Click "Send your first message"
3. Enter notification title and text
4. Select your app as target
5. Click "Send test message"
6. Enter your FCM token (logged in debug console)
7. Click "Test"

### Using Backend API
The Money Guardian backend can send notifications when:
- A subscription is about to charge
- An overdraft warning is triggered
- A price increase is detected

See `backend/app/services/notification_service.py` for implementation.
