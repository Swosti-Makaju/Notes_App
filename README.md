#Minimalist Notes App

A lightweight, production-ready Flutter notes application designed with a clean Material 3 interface and reliable offline data persistence.

🚀 Features
Offline-First Storage: Local data persistence using a structured SQLite database (sqflite).

Intuitive UI/UX: Built a smooth, full-screen notepad editor that works seamlessly for both creating and editing notes.

Light on Memory: Written with clean code habits that automatically free up phone memory when you close pages, keeping the app fast and lag-free.

Smart Saving: Automatically names notes "Untitled" if you forget a title, and saves the modification date every time you save.

🔧 Getting Started
Prerequisites
Flutter SDK (Stable Channel)

Android Studio / Xcode (configured for mobile simulation platforms)

Installation & Setup
Follow these steps to get the project running locally:

Bash
# 1. Clone the project repository
git clone https://github.com/Swosti-Makaju/Notes_App.git

# 2. Navigate into the project directory
cd Notes_App

# 3. Pull required ecosystem packages
flutter pub get

# 4. Boot up your target emulator or physical deployment platform and run
flutter run

🛠️ Tech Stack & Packages

Framework: Flutter (Dart)

Local Database: sqflite (SQLite plugin for Flutter)