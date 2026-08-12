
export PATH=${TOOLS_PATH}/flutter/bin:$PATH

# JDK 17 — required by Android Gradle Plugin 8.x (cask temurin@17)
if [[ -d /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home ]]; then
  export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
  export PATH=$JAVA_HOME/bin:$PATH
fi

# Android SDK. Canonical location (shared with Android Studio); brew's
# android-commandlinetools only supplies sdkmanager/avdmanager, which install
# components here via --sdk_root.
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# Pin where AVDs live. Without this the two tools disagree: newer avdmanager honours
# XDG_CONFIG_HOME and writes to ~/.config/.android/avd, while the emulator only
# searches $ANDROID_AVD_HOME, $ANDROID_SDK_HOME/avd and ~/.android/avd — so a created
# AVD fails with "Unknown AVD name".
export ANDROID_AVD_HOME=$HOME/.android/avd
export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/tools/bin:$PATH
export PATH=/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin:$PATH
