<p align="center">
  <img src="Care+/Care+/Assets.xcassets/logonome.imageset/logonome.png" width="120" />
</p>

<h1 align="center">Alzheimer Care</h1>

<p align="center">
  Accessible iOS support for patients and caregivers
</p>

---

## 🧠 About the App

**Alzheimer Care** is an iOS application designed to support coordination between patients affected by Alzheimer’s disease and their caregivers.

The app provides a shared digital environment where daily care activities can be organized, memories and health-related notes can be recorded, and a linked patient and caregiver can communicate privately.

---

## ✨ Key Features

- 🗂 Task and medication management  
- 💊 Home medicine cabinet with stock, purpose, storage location and expiry alerts
- 📔 Personal diary (text, images, audio, and video)  
- 💬 Persistent patient-caregiver chat
- 📞 Contact and call management  
- 🌗 Light and dark mode support  

---

## 🛠 Technology Stack

- Swift  
- SwiftUI  
- iOS SDK  
- Supabase Auth, Postgres and Row Level Security

## ✅ Current status

- Patient and caregiver are distinct account roles.
- A profile must complete role-specific setup before entering the app.
- Care links are validated by the other account's email and role.
- Chat messages are stored in Supabase and are visible only to members of the active care link.
- A caregiver works on the linked patient's shared tasks and diary, while personal contacts, calls and game results stay account-scoped.
- Tasks, diary entries, contacts, calls and game results are isolated per local account.
- Email authentication is active. Apple and Google buttons remain visible as clearly marked placeholders until their Supabase provider configuration is completed.

## 🚀 Run locally

Requirements:

- Xcode 16 or later
- iOS 17 or later
- A Supabase project

Setup:

1. Open `Care+/Care+.xcodeproj` in Xcode.
2. In the Xcode scheme, add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` under **Run → Arguments → Environment Variables**. For an archived app, provide the same keys through its generated Info.plist/build configuration.
3. Run `supabase/migrations/202609100001_careplus_core.sql` once in the Supabase SQL editor.
4. Build the `Care+` scheme on an iPhone simulator or device.

To test the shared flow, create two email accounts. Choose **Patient** for one and **Caregiver** for the other, then enter the counterpart's email during setup on both accounts. The first request stays pending; the matching request from the other account activates the connection. The migration creates the required tables, profile trigger, consent-based link function and access policies.

## 🔐 Privacy and safety

Database access is protected with Supabase Row Level Security. A user can read a conversation only when their authenticated account belongs to its active care link. The app is a coordination and memory-support project; it is not a diagnostic tool and must not replace professional medical advice or emergency services.

---

## 👥 Team

- Antonio Ferone  
- Mouchtakiri Azzeddine  
---

## 📂 Project Notes

This repository contains the source code of the iOS application.

User-specific files, build artifacts, and sensitive configuration data are excluded from version control.

---

## 📅 Academic Context

Developed during an Apple Developer Academy Foundation Program project.
Year: 2025–2026
