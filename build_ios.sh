#!/bin/bash

# CloudBeatz iOS Build & Packaging Script
# This script automates the generation of an iOS app bundle (.ipa) on a Mac
# without requiring an expensive Apple Developer Account (no-codesign).
# Perfect for easy sideloading using AltStore, Sideloadly, Scarlet, or TrollStore.

# Exit immediately if any command fails
set -e

echo "====================================================="
echo "🎵 Preparing to build CloudBeatz for iOS 🎵"
echo "====================================================="

# Step 1: Clean and get dependencies
echo "🧹 Cleaning previous build artifacts..."
flutter clean

echo "📦 Fetching Flutter dependencies..."
flutter pub get

# Step 2: iOS CocoaPods setup
cd ios

echo "⚙️ Updating CocoaPods repository and installing pods..."
# Remove existing lock file and Pods directory if they exist to prevent caching issues
rm -rf Podfile.lock Pods/
pod install --repo-update

cd ..

# Step 3: Build Unsigned IPA
echo "🚀 Building release IPA (unsigned)..."
# We build with --no-codesign so that anyone can build it on a Mac without provisioning profile errors.
flutter build ipa --release --no-codesign

echo "====================================================="
echo "✅ Build Completed Successfully! ✅"
echo "====================================================="
echo "Your unsigned app bundle is ready!"
echo "You can find the build outputs at:"
echo "📂 build/ios/ipa/"
echo "====================================================="
echo "👉 HOW TO SIDELOAD:"
echo "1. Copy the .ipa file from 'build/ios/ipa/' to your device or Mac."
echo "2. Use Sideloadly (sideloadly.io) or AltStore (altstore.io) to install."
echo "   These tools will sign the app automatically using your free Apple ID."
echo "====================================================="
