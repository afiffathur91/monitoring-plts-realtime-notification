// PZEM-017 DC Energy Meter - Firebase Monitoring (Simplified: 4 Parameters)
// Parameters: Voltage, Current, Power, Energy
// WiFi & Device ID: Hardcoded

#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <SoftwareSerial.h>
#include <ModbusMaster.h>

/* ------------------- KONFIGURASI WIFI & FIREBASE ------------------- */
#define WIFI_SSID "Nama Wifi"          // Ganti dengan Nama WiFi Anda
#define WIFI_PASSWORD "PAssword"     // Ganti dengan Password WiFi Anda
#define DEVICE_ID "Panel_Surya_ID"    // ID Alat

#define FIREBASE_HOST "YOUR_FIREBASE_DATABASE_HOST"
#define FIREBASE_AUTH "YOUR_FIREBASE_DATABASE_SECRET"

// ============ Global Objects ============
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ============ PZEM-017 + MAX485 ============
#define MAX485_DE 16   // D0 - DE pin of MAX485
#define MAX485_RE 5    // D1 - RE pin of MAX485
// PZEM Serial: Rx = GPIO 4 (D2), Tx = GPIO 0 (D3)
SoftwareSerial PZEMSerial;

static uint8_t pzemSlaveAddr = 0x01;
static uint16_t NewshuntAddr = 0x0001;  // 0x0001 = 50A Shunt

ModbusMaster node;

float PZEMVoltage = 0;
float PZEMCurrent = 0;
float PZEMPower = 0;
float PZEMEnergy = 0;

unsigned long startMillisPZEM = 0;
unsigned long currentMillisPZEM = 0;
const unsigned long periodPZEM = 1000;  // Baca sensor tiap 1 detik

unsigned long startMillis1 = 0;         // Startup delay
int a = 1;                              // Flag untuk setup awal

// ============ Firebase send interval ============
unsigned long lastReadingTime = 0;
const unsigned long READ_INTERVAL = 5000;  // Kirim ke Firebase tiap 5 detik

// ============ NTP (UTC) ============
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "id.pool.ntp.org");

// ============ Modbus Functions ============
void preTransmission() {
  if (millis() - startMillis1 > 5000) {
    digitalWrite(MAX485_RE, 1);
    digitalWrite(MAX485_DE, 1);
    delay(1);
  }
}

void postTransmission() {
  if (millis() - startMillis1 > 5000) {
    delay(3);
    digitalWrite(MAX485_RE, 0);
    digitalWrite(MAX485_DE, 0);
  }
}

void setShunt(uint8_t slaveAddr) {
  static uint8_t SlaveParameter = 0x06;
  static uint16_t registerAddress = 0x0003;

  uint16_t u16CRC = 0xFFFF;
  u16CRC = crc16_update(u16CRC, slaveAddr);
  u16CRC = crc16_update(u16CRC, SlaveParameter);
  u16CRC = crc16_update(u16CRC, highByte(registerAddress));
  u16CRC = crc16_update(u16CRC, lowByte(registerAddress));
  u16CRC = crc16_update(u16CRC, highByte(NewshuntAddr));
  u16CRC = crc16_update(u16CRC, lowByte(NewshuntAddr));

  preTransmission();
  PZEMSerial.write(slaveAddr);
  PZEMSerial.write(SlaveParameter);
  PZEMSerial.write(highByte(registerAddress));
  PZEMSerial.write(lowByte(registerAddress));
  PZEMSerial.write(highByte(NewshuntAddr));
  PZEMSerial.write(lowByte(NewshuntAddr));
  PZEMSerial.write(lowByte(u16CRC));
  PZEMSerial.write(highByte(u16CRC));
  delay(10);
  postTransmission();
  delay(100);
}

void changeAddress(uint8_t OldslaveAddr, uint8_t NewslaveAddr) {
  static uint8_t SlaveParameter = 0x06;
  static uint16_t registerAddress = 0x0002;

  uint16_t u16CRC = 0xFFFF;
  u16CRC = crc16_update(u16CRC, OldslaveAddr);
  u16CRC = crc16_update(u16CRC, SlaveParameter);
  u16CRC = crc16_update(u16CRC, highByte(registerAddress));
  u16CRC = crc16_update(u16CRC, lowByte(registerAddress));
  u16CRC = crc16_update(u16CRC, highByte(NewslaveAddr));
  u16CRC = crc16_update(u16CRC, lowByte(NewslaveAddr));

  preTransmission();
  PZEMSerial.write(OldslaveAddr);
  PZEMSerial.write(SlaveParameter);
  PZEMSerial.write(highByte(registerAddress));
  PZEMSerial.write(lowByte(registerAddress));
  PZEMSerial.write(highByte(NewslaveAddr));
  PZEMSerial.write(lowByte(NewslaveAddr));
  PZEMSerial.write(lowByte(u16CRC));
  PZEMSerial.write(highByte(u16CRC));
  delay(10);
  postTransmission();
  delay(100);
}

// ============ SETUP ============
void setup() {
  Serial.begin(9600);
  delay(1000);

  Serial.println("\n\nPZEM-017 PLTS Monitor (4 Parameters Only)");
  Serial.println("-----------------------------------------");

  // PZEM: Rx = D2 (GPIO 4), Tx = D3 (GPIO 0)
  PZEMSerial.begin(9600, SWSERIAL_8N2, 4, 0);

  pinMode(MAX485_RE, OUTPUT);
  pinMode(MAX485_DE, OUTPUT);
  digitalWrite(MAX485_RE, 0);
  digitalWrite(MAX485_DE, 0);

  node.preTransmission(preTransmission);
  node.postTransmission(postTransmission);
  node.begin(pzemSlaveAddr, PZEMSerial);

  startMillis1 = millis();
  startMillisPZEM = millis();

  // Koneksi WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Menghubungkan ke WiFi: ");
  Serial.println(WIFI_SSID);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    attempts++;
    if(attempts > 40) { 
       Serial.println("\nGagal Konek. Restarting...");
       ESP.restart();
    }
  }

  Serial.println("\nWiFi Terhubung!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  // NTP Client
  timeClient.begin();
  timeClient.setTimeOffset(0);  
  timeClient.update();

  // Firebase Init
  config.database_url = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("System Ready.");
  lastReadingTime = millis();
}

// ============ LOOP ============
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi Lost...");
    return;
  }

  currentMillisPZEM = millis();

  // One-time: set shunt and meter address (setelah 10 detik)
  if ((millis() - startMillis1 >= 10000) && (a == 1)) {
    setShunt(pzemSlaveAddr);
    changeAddress(0xF8, pzemSlaveAddr);
    a = 0;
    Serial.println("Config PZEM Done.");
  }

  // Read PZEM-017
  if (currentMillisPZEM - startMillisPZEM >= periodPZEM) {
    uint8_t result = node.readInputRegisters(0x0000, 6);
    if (result == node.ku8MBSuccess) {
      uint32_t tempdouble = 0x00000000;
      
      // 1. Tegangan (Voltage)
      PZEMVoltage = node.getResponseBuffer(0x0000) / 100.0;
      
      // 2. Arus (Current)
      PZEMCurrent = node.getResponseBuffer(0x0001) / 100.0;
      
      // 3. Daya (Power)
      tempdouble = (node.getResponseBuffer(0x0003) << 16) + node.getResponseBuffer(0x0002);
      PZEMPower = tempdouble / 10.0;
      
      // 4. Energi (Energy)
      tempdouble = (node.getResponseBuffer(0x0005) << 16) + node.getResponseBuffer(0x0004);
      PZEMEnergy = tempdouble;
      
    } else {
      Serial.println("Gagal Baca Sensor PZEM");
    }
    startMillisPZEM = currentMillisPZEM;
  }

  // Send to Firebase
  unsigned long now = millis();
  if (now - lastReadingTime >= READ_INTERVAL) {
    
    timeClient.update();
    const unsigned long epoch = (unsigned long)timeClient.getEpochTime();

    // Print Serial Monitor
    Serial.print("V: "); Serial.print(PZEMVoltage);
    Serial.print(" | I: "); Serial.print(PZEMCurrent);
    Serial.print(" | P: "); Serial.print(PZEMPower);
    Serial.print(" | E: "); Serial.println(PZEMEnergy);

    if (Firebase.ready()) {
      FirebaseJson json;
      
      // --- HANYA 4 PARAMETER UTAMA ---
      json.add("Voltage", PZEMVoltage);   // Tegangan
      json.add("Current", PZEMCurrent);   // Arus
      json.add("Power", PZEMPower);       // Daya
      json.add("Energy", PZEMEnergy);     // Energi
      
      // Metadata (Wajib untuk database terstruktur)
      json.add("timestamp", epoch);
      json.add("deviceId", DEVICE_ID);

      // Kirim Data History ke path: /devices/{ID}/data/{timestamp}
      String dataPath = "/devices/" + String(DEVICE_ID) + "/data/" + String(epoch);
      
      if (Firebase.setJSON(fbdo, dataPath, json)) {
         Serial.println("Data Terkirim ke Firebase!");
         
         // Update Last Seen (Metadata alat)
         String devicePath = "/devices/" + String(DEVICE_ID);
         FirebaseJson deviceJson;
         deviceJson.add("lastSeen", (unsigned long)(epoch * 1000UL));
         deviceJson.add("lastSeenFormatted", timeClient.getFormattedTime());
         Firebase.updateNode(fbdo, devicePath, deviceJson);

      } else {
         Serial.print("Firebase Error: ");
         Serial.println(fbdo.errorReason());
      }
    }

    lastReadingTime = now;
  }
}
