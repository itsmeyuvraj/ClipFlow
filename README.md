# ClipFlow (YouTube Downloader) 🎬

A native, modern macOS YouTube video and audio downloader built with **SwiftUI** and **yt-dlp**.

Designed specifically to adhere to Apple's modern macOS design language with frosted glass materials (`.ultraThinMaterial`), native SF Symbols, system typography, restrained accents, and comprehensive format support.

---

## ✨ Features

- **Apple HIG Native Aesthetic**:
  - Translucent materials, sidebar navigation, unified toolbar, and dark/light mode support.
  - Non-flashy, elegant Apple-standard design.
- **Support for All Video & Audio Formats**:
  - **Quick Presets**: 4K Ultra HD (2160p), 2K Quad HD (1440p), 1080p Full HD 60fps, 720p HD, 480p, and 360p Data Saver.
  - **Container Options**: MP4, MKV, WebM, MOV.
  - **Audio Extraction**: Universal MP3 (320 kbps), Apple Native AAC (M4A), Lossless FLAC, Uncompressed WAV, and Opus.
  - **Stream Inspector (All Formats Matrix)**: Inspect and select *any* specific stream ID, codec (AV1, VP9, H.264), bitrate, or fps directly from YouTube.
- **Rich Video Preview**:
  - Live thumbnail with duration badge.
  - Channel name, view count, published date, and total stream count.
  - Direct button to open the video in your default browser.
- **Smart Downloads Engine**:
  - Powered by `yt-dlp` and `ffmpeg`.
  - Non-blocking async process streaming with real-time download percentage, transfer speed, and ETA.
  - Automatic stream muxing (video-only stream merged seamlessly with high-bitrate audio).
  - Thumbnail embedding, chapter marker tagging, and subtitle extraction.
- **Queue & History**:
  - Live active downloads queue with cancellation controls.
  - Persistent download history saved in `~/Library/Application Support/ClipFlow/`.
  - "Show in Finder" and "Quick Play" actions.
- **System Integration**:
  - Automatic clipboard URL detection on launch or focus.
  - Native macOS user notifications when downloads complete.
  - Packaged as a standalone native `.app` bundle with high-resolution Retina `AppIcon.icns`.

---

## 🚀 How to Run & Build

### Running the App
The compiled app bundle is located at:
```bash
/Users/yuvraj/Documents/Projects/ClipFlow/ClipFlow.app
```

To launch it immediately:
```bash
open /Users/yuvraj/Documents/Projects/ClipFlow/ClipFlow.app
```

Or to install it to your Applications folder:
```bash
cp -r /Users/yuvraj/Documents/Projects/ClipFlow/ClipFlow.app /Applications/
```

### Running in Xcode
Double-click `ClipFlow.xcodeproj` or open it in Xcode:
```bash
open ClipFlow.xcodeproj
```
Select the **ClipFlow** scheme and press **Cmd + R** (Run).

### Rebuilding from Source (Command Line)
```bash
cd /Users/yuvraj/Documents/Projects/ClipFlow
./bundle_app.sh
```

### Running Tests
```bash
swift test
```

---

## 🛠 System Dependencies

ClipFlow automatically detects the following command-line tools installed via Homebrew:
- `yt-dlp` (`/opt/homebrew/bin/yt-dlp`)
- `ffmpeg` (`/opt/homebrew/bin/ffmpeg`)

If installed in custom locations, you can configure their paths directly in **ClipFlow Settings**.
