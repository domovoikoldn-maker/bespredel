#!/usr/bin/env bash
# Донастройка gradle-файлов, сгенерированных `flutter create`:
#  - minSdk 24 (ядра собраны под API 24)
#  - только arm64-v8a и x86_64
#  - useLegacyPackaging: .so распаковываются на диск, чтобы их можно было запускать как процессы
set -euo pipefail
cd "$(dirname "$0")/../android/app"

if [ -f build.gradle ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' build.gradle
  cat >> build.gradle <<'EOF'

android {
    defaultConfig {
        ndk { abiFilters 'arm64-v8a', 'x86_64' }
    }
    packagingOptions {
        jniLibs { useLegacyPackaging = true }
    }
}
EOF
elif [ -f build.gradle.kts ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' build.gradle.kts
  cat >> build.gradle.kts <<'EOF'

android {
    defaultConfig {
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }
    packaging {
        jniLibs { useLegacyPackaging = true }
    }
}
EOF
else
  echo "build.gradle не найден" >&2
  exit 1
fi
echo "android/app gradle пропатчен"
