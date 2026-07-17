# Monitoring PLTS — Solar Power Monitoring System

Aplikasi **Flutter** untuk memantau performa Pembangkit Listrik Tenaga Surya (PLTS) secara real-time, dengan integrasi **Firebase Realtime Database**, sensor **PZEM-017**, dan firmware **ESP8266**.

## Fitur utama

- **Dashboard** — tegangan, arus, daya, energi (kWh) real-time + grafik
- **Real-time monitoring** — stream data langsung dari Firebase
- **Data History** — filter harian, ringkasan kWh, grafik mingguan, ekspor CSV/PDF
- **Analytics** — analisis data & forecasting
- **Notifikasi** — alert threshold (lokal, Telegram)
- **Multi-device** — pilih perangkat PLTS aktif
- **Firmware Arduino** — ESP8266 kirim data ke Firebase

## Tech stack

| Layer | Teknologi |
|-------|-----------|
| Mobile | Flutter, Provider |
| Backend | Firebase Auth, Realtime Database |
| Visualisasi | fl_chart |
| Hardware | Penel Surya,ESP8266, PZEM-017 (Modbus RS485), MAX485 |
| Export | CSV, PDF (share_plus) |

## Arsitektur

```
PZEM-017 → ESP8266 → Firebase Realtime DB (/devices/{id}/data/{ts}) → Flutter App
```

## Screenshots

> Tambahkan screenshot ke folder `assets/images/` dan lampirkan di sini untuk portofolio.

## Menjalankan project

### Prasyarat

- Flutter SDK 3.6+
- Android Studio / VS Code
- Akun Firebase (project `mobile-plts-afif` atau ganti dengan project Anda)

### Langkah

```bash
git clone https://github.com/USERNAME/monitoring_plts.git
cd monitoring_plts
flutter pub get
flutter run
```

### Build APK release

```bash
flutter build apk --release
```

## Struktur folder penting

```
lib/
  main.dart                 # Entry point
  providers/                # State management (Solar, Auth, Device)
  screens/                  # UI (Dashboard, History, Analytics, Settings)
  services/                 # Firebase, export, notifikasi
  models/                   # SolarData, Settings, Device
arduino/plts_monitoring/    # Firmware ESP8266 + PZEM
```

## Keamanan (penting sebelum repo publik)

- **Rotasi** Firebase Database secret / legacy token di firmware Arduino jika repo ini publik
- Perketat **Firebase Database Rules** untuk path `/devices`
- Batasi API key Firebase di Google Cloud Console (package Android + SHA-1)
- Jangan commit file `key.properties` atau `*.jks`
