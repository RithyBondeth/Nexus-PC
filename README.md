# 🚀 Nexus-PC (Stratum Engine)
> **The Zero-Configuration, Plug-and-Play PC Game Runner for Android**

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-blue?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Platform-Android_12%2B-green?logo=android)](https://developer.android.com)
[![Status](https://img.shields.io/badge/Status-Active_Development-orange)]()

**Nexus-PC** is a next-generation Android application that bridges the gap between desktop PC gaming and mobile hardware. Existing Windows translation layers on mobile require tedious container creation, manual driver installation, and complex keymapping. Nexus-PC eliminates this friction entirely via an automated **Cloud Fingerprinting & SoC Alias Normalization** engine.

Simply import your DRM-free game directory or archive, and the app automatically provisions the right translation runtime, injects optimized Mesa Turnip graphics drivers, and launches your game seamlessly.

---

## ✨ Key Features

* **🔌 True Plug-and-Play UX:** No manual Wine prefixes, DXVK toggles, or container configuration required. 
* **⚡ Flutter-Powered Dashboard:** A gorgeous, high-performance UI built with Flutter and Isar DB for lightning-fast local library management.
* **🧠 Automated Cloud Profile Matching:** Automatically detects your device chipset and fetches community-verified execution flags via a lightweight cloud backend.
* **🌐 Universal SoC Abstraction:** Future-proof architecture featuring server-side alias normalization to instantly support evolving Qualcomm Snapdragon tiers (Gen 2, Gen 3, Elite, and beyond) without client app updates.
* **🎮 Smart Touch & Controller Overlays:** Automatically maps contextual on-screen gamepads or translates inputs directly via zero-latency C++ XInput bridges.