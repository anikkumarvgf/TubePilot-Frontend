#!/bin/bash
echo "🚀 Starting Complete Flutter & Android SDK Environment Setup..."

# 1. Update and install basic dependencies
sudo apt-get update && sudo apt-get install -y curl git unzip libglu1-mesa wget

# 2. Install Java (JDK 17) required for Android builds
echo "☕ Installing OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc

# 3. Install Flutter SDK (Stable Channel)
echo "💙 Installing Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
export PATH="$PATH:$HOME/development/flutter/bin"
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc

# 4. Configure Flutter (Disable analytics & setup Android toolchain)
flutter config --no-analytics
flutter precache

# 5. Install Android Command-Line Tools & SDKs
echo "🤖 Setting up Android SDK..."
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O commandlinetools.zip
unzip -q commandlinetools.zip
rm commandlinetools.zip
mkdir -p latest
mv bin lib source.properties notice readme.txt latest/ 2>/dev/null || true

# Set Android Home Path
export ANDROID_HOME=$HOME/android-sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
echo "export ANDROID_HOME=$HOME/android-sdk" >> ~/.bashrc
echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"' >> ~/.bashrc

# Accept Android Licenses and Install Build-Tools / Platforms
echo "accept" | sdkmanager --sdk_root=$HOME/android-sdk --licenses > /dev/null 2>&1
sdkmanager --sdk_root=$HOME/android-sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# 6. Final Flutter Doctor check
flutter doctor --android-licenses || true
flutter doctor

echo "✅ Setup Completed Successfully! Boss, your environment is ready."