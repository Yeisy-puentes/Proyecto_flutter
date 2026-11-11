#!/bin/bash
# Prepara el proyecto Interfajas en tu Mac (ejecútalo UNA vez dentro de la carpeta).
#   cd ~/interfajas_app && bash preparar.sh
set -e

echo "1/5 Creando carpetas de iOS, Android y web (no toca lib/)..."
flutter create --org co.interfajas --project-name interfajas_app \
  --platforms ios,android,web .

echo "2/5 Instalando paquetes..."
flutter pub get

echo "3/5 Permiso de ubicación en iOS (Info.plist)..."
PLIST=ios/Runner/Info.plist
if ! grep -q NSLocationWhenInUseUsageDescription "$PLIST"; then
  /usr/libexec/PlistBuddy -c "Add :NSLocationWhenInUseUsageDescription string Interfajas usa tu ubicación para mostrar la ruta hasta la casa del cliente." "$PLIST"
fi
# Firebase pide iOS 15 como mínimo (igual que en clase_noche)
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 1[0-4]\.[0-9]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
  ios/Runner.xcodeproj/project.pbxproj
if [ -f ios/Podfile ]; then
  sed -i '' "s/^# platform :ios.*/platform :ios, '15.0'/" ios/Podfile
fi

echo "4/5 Permisos de ubicación e internet en Android..."
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$MANIFEST"; then
  sed -i '' 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\
    <uses-permission android:name="android.permission.INTERNET"/>\
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>#' "$MANIFEST"
fi

echo "5/5 Listo. Ahora conecta tu proyecto NUEVO de Firebase con:"
echo "    flutterfire configure"
echo "(elige el proyecto de Interfajas y marca ios, android y web)"
