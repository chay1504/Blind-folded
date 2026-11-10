# Codex Remote

Two full-screen Android buttons press the native **Dictate** and **Voice chat** controls in the foreground Codex desktop chat. Use the same button again to stop its mode. The laptop handles the microphone, transcription, and voice replies using its normal Codex settings.

## Download

[Download the two-file package](deliverables/Codex-Remote-0.2.0-share.zip?raw=true) for the Android APK and standalone Windows launcher. Extract the ZIP before running the launcher. If ADB isn't installed, extract Android SDK Platform-Tools into a `platform-tools` folder next to the standalone launcher.

[Download just the APK](deliverables/Codex-Remote-0.2.0.apk?raw=true). The `0.1.0` kit in the deliverables folder is an earlier prototype.

## Setup

1. Install the APK on an Android phone, turn on USB debugging, and plug it into the Windows laptop. Accept the laptop's debugging prompt on the phone. If ADB is missing on the laptop, install [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools).
2. Double-click **Start Codex Remote.cmd** from the two-file package or **Start Round.cmd** from the source folder. In Codex on the laptop, open the round chat, make sure its Dictate and Voice chat buttons are available, and leave that chat in front.
3. Open **Codex Remote** on the phone, enter the six-digit code from the launcher, and dismiss Android's first full-screen tip if it appears. Test both halves before putting on the blindfold.

The **top half** presses Dictate or Stop dictation. Codex leaves the transcription in the composer as a draft, as it does when you click Dictate on the laptop. The **bottom half** presses Start voice chat or End voice chat in the open chat. Set up the Codex microphone permission and headset on the laptop before the round.

A short vibration means the press reached its button. Two longer pulses mean the remote could not press it. Check the launcher for the reason. Keep the round chat visible and in the foreground. The bridge matches the English desktop button labels, so set the desktop app language to English for this version. If your laptop offers voice only in new chats, open a chat that already has the Start voice chat control available.

If the phone disconnects, reconnect USB. If the remote still fails, reopen the launcher and pair with its new code. Use the laptop to stop any active recording if the phone is disconnected. Close the launcher to end the remote session.

## Build the APK

Set JAVA_HOME to JDK 17 and ANDROID_HOME to an Android SDK with API 36. Run gradlew.bat :app:assembleDebug :app:lintDebug. The APK is under app/build/outputs/apk/debug.
