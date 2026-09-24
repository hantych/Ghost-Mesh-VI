# Ghost Mesh Offline 📡

P2P мессенджер без сервера. Работает через Bluetooth BLE (до ~50м) и WebRTC P2P (через интернет, без своего сервера).

## Сборка APK через GitHub Actions

1. Создай репозиторий на GitHub
2. Залей все файлы из этой папки
3. Перейди в **Actions** → **Build Ghost Mesh Offline APK** → **Run workflow**
4. После завершения скачай APK из **Artifacts**

## Локальная сборка

```bash
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

## Требования
- Android 5.0+ (API 21)
- Bluetooth для BLE радара
- Интернет для WebRTC P2P (опционально)

## Функции
- 📡 BLE радар — видит устройства рядом
- 🌐 WebRTC P2P — через интернет без сервера
- 👻 Ghost режим — сообщения исчезают при отключении
- 🎨 6 цветовых тем, настраиваемые пузыри, фоны чата
