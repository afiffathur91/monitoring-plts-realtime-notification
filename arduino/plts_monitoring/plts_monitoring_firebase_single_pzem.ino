// PZEM-017 DC Energy Meter - Firebase Monitoring (converted from Blynk)
// Single PZEM-017 + MAX485 RS485, WiFi config via AP, data sent to Firebase for Flutter app

#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <ESP8266WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <SoftwareSerial.h>
#include <ModbusMaster.h>

// ============ Access Point (first-time WiFi config) ============
const char* AP_SSID = "PLTS_Monitor_AP";
const byte DNS_PORT = 53;
IPAddress apIP(192, 168, 4, 1);
DNSServer dnsServer;
ESP8266WebServer webServer(80);

struct Settings {
  char ssid[32];
  char password[64];
  char deviceId[32];
  bool configured;
} settings;

// ============ Firebase ============
#define FIREBASE_HOST "YOUR_FIREBASE_DATABASE_HOST"
#define FIREBASE_AUTH "YOUR_FIREBASE_DATABASE_SECRET"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ============ PZEM-017 + MAX485 (Solarduino style) ============
#define MAX485_DE 16   // D0 - DE pin of MAX485
#define MAX485_RE 5    // D1 - RE pin of MAX485
// PZEM Serial: Rx = GPIO 4 (D2), Tx = GPIO 0 (D3)
SoftwareSerial PZEMSerial;

static uint8_t pzemSlaveAddr = 0x01;
static uint16_t NewshuntAddr = 0x0001;  // 0x0000=100A, 0x0001=50A, 0x0002=200A, 0x0003=300A

ModbusMaster node;

float PZEMVoltage = 0;
float PZEMCurrent = 0;
float PZEMPower = 0;
float PZEMEnergy = 0;

unsigned long startMillisPZEM = 0;
unsigned long currentMillisPZEM = 0;
const unsigned long periodPZEM = 1000;  // read PZEM every 1 second

unsigned long startMillis1 = 0;         // startup delay for Serial/ESP
int a = 1;                              // first run: set shunt & address

// ============ Firebase send interval ============
unsigned long lastReadingTime = 0;
const unsigned long READ_INTERVAL = 5000;  // send to Firebase every 5 seconds

// ============ NTP (UTC) ============
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "id.pool.ntp.org");
bool timeSynced = false;

// ============ Setup HTML ============
const char* configHTML = R"html(
<!DOCTYPE html>
<html>
<head>
    <title>PLTS Monitor Setup</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; margin: 0 auto; padding: 20px; max-width: 600px; }
        input, button { display: block; width: 100%; margin: 10px 0; padding: 10px; }
        button { background: #4CAF50; color: white; border: none; border-radius: 4px; }
    </style>
</head>
<body>
    <h2>PLTS Monitor Setup</h2>
    <form action="/save" method="POST">
        <input type="text" name="deviceid" placeholder="Device ID" required>
        <input type="text" name="ssid" placeholder="WiFi Name" required>
        <input type="password" name="password" placeholder="WiFi Password" required>
        <button type="submit">Save and Connect</button>
    </form>
</body>
</html>
)html";

#define EEPROM_MAGIC 0x42
#define EEPROM_MAGIC_ADDR 0
#define EEPROM_SETTINGS_ADDR 1

void loadSettings() {
  EEPROM.begin(512);
  byte magic = EEPROM.read(EEPROM_MAGIC_ADDR);
  if (magic == EEPROM_MAGIC) {
    EEPROM.get(EEPROM_SETTINGS_ADDR, settings);
    Serial.println("Loaded settings from EEPROM");
  } else {
    memset(&settings, 0, sizeof(settings));
    settings.configured = false;
    EEPROM.write(EEPROM_MAGIC_ADDR, EEPROM_MAGIC);
    EEPROM.put(EEPROM_SETTINGS_ADDR, settings);
    EEPROM.commit();
    Serial.println("EEPROM uninitialized - wrote default settings");
  }
  EEPROM.end();
}

void saveSettings() {
  EEPROM.begin(512);
  EEPROM.write(EEPROM_MAGIC_ADDR, EEPROM_MAGIC);
  EEPROM.put(EEPROM_SETTINGS_ADDR, settings);
  EEPROM.commit();
  EEPROM.end();
  Serial.println("Settings saved to EEPROM");
}

void setupAccessPoint() {
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(AP_SSID);
  Serial.print("Started AP: ");
  Serial.println(AP_SSID);
  Serial.println(WiFi.softAPIP());

  dnsServer.start(DNS_PORT, "*", apIP);

  webServer.on("/", HTTP_GET, []() {
    webServer.send(200, "text/html", configHTML);
  });

  webServer.on("/save", HTTP_POST, []() {
    String deviceId = webServer.arg("deviceid");
    String ssid = webServer.arg("ssid");
    String password = webServer.arg("password");

    if (deviceId.length() == 0 || ssid.length() == 0) {
      webServer.send(400, "text/plain", "Device ID and WiFi Name are required");
      return;
    }

    WiFi.begin(ssid.c_str(), password.c_str());
    Serial.print("Testing WiFi: ");
    Serial.println(ssid);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 10) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\nWiFi failed");
      webServer.send(400, "text/plain", "Could not connect to WiFi. Check SSID and password.");
      WiFi.disconnect();
      return;
    }

    Serial.println("\nWiFi OK, saving...");
    deviceId.toCharArray(settings.deviceId, sizeof(settings.deviceId));
    ssid.toCharArray(settings.ssid, sizeof(settings.ssid));
    password.toCharArray(settings.password, sizeof(settings.password));
    settings.configured = true;
    saveSettings();

    String response = "Settings saved. Device ID: " + deviceId + "\nWiFi: " + ssid + "\nIP: " + WiFi.localIP().toString();
    webServer.send(200, "text/plain", response);
    delay(1000);
    dnsServer.stop();
    webServer.stop();
    WiFi.softAPdisconnect(true);
    Serial.println("Starting monitoring...");
  });

  webServer.begin();
}

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

void setup() {
  Serial.begin(9600);
  delay(1000);

  Serial.println("\n\nPZEM-017 PLTS Monitor (Firebase)");
  Serial.println("-------------------------------");

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

  loadSettings();

  if (!settings.configured) {
    Serial.println("No config. Starting setup AP...");
    setupAccessPoint();
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(true);
  WiFi.begin(settings.ssid, settings.password);

  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi failed. Restarting to AP...");
    settings.configured = false;
    saveSettings();
    ESP.restart();
    return;
  }

  Serial.println();
  Serial.print("Connected: ");
  Serial.println(WiFi.localIP());

  timeClient.begin();
  timeClient.setTimeOffset(0);  // UTC

  Serial.println("Syncing NTP...");
  for (int i = 0; i < 10; i++) {
    if (timeClient.update()) break;
    timeClient.forceUpdate();
    delay(500);
  }
  timeSynced = (unsigned long)timeClient.getEpochTime() > 1700000000UL;
  Serial.printf("NTP: %s, epoch=%lu\n", timeSynced ? "OK" : "NO", (unsigned long)timeClient.getEpochTime());

  config.database_url = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  int fbAttempts = 0;
  while (!Firebase.ready() && fbAttempts < 3) {
    Serial.println("Waiting for Firebase...");
    delay(1000);
    fbAttempts++;
  }

  if (!Firebase.ready()) {
    Serial.println("Firebase failed. Restarting...");
    settings.configured = false;
    saveSettings();
    ESP.restart();
    return;
  }

  Serial.println("Firebase OK");
  lastReadingTime = millis();
}

void loop() {
  if (!settings.configured) {
    dnsServer.processNextRequest();
    webServer.handleClient();
    return;
  }

  if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
    return;
  }

  currentMillisPZEM = millis();

  // One-time: set shunt and meter address (after 10 s)
  if ((millis() - startMillis1 >= 10000) && (a == 1)) {
    setShunt(pzemSlaveAddr);
    changeAddress(0xF8, pzemSlaveAddr);
    a = 0;
  }

  // Read PZEM-017
  if (currentMillisPZEM - startMillisPZEM >= periodPZEM) {
    uint8_t result = node.readInputRegisters(0x0000, 6);
    if (result == node.ku8MBSuccess) {
      uint32_t tempdouble = 0x00000000;
      PZEMVoltage = node.getResponseBuffer(0x0000) / 100.0;
      PZEMCurrent = node.getResponseBuffer(0x0001) / 100.0;
      tempdouble = (node.getResponseBuffer(0x0003) << 16) + node.getResponseBuffer(0x0002);
      PZEMPower = tempdouble / 10.0;
      tempdouble = (node.getResponseBuffer(0x0005) << 16) + node.getResponseBuffer(0x0004);
      PZEMEnergy = tempdouble;
    }
    startMillisPZEM = currentMillisPZEM;
  }

  // Send to Firebase every READ_INTERVAL
  unsigned long now = millis();
  if (now - lastReadingTime >= READ_INTERVAL) {
    if (!timeClient.update()) {
      timeClient.forceUpdate();
    }
    if (!timeSynced) {
      timeSynced = (unsigned long)timeClient.getEpochTime() > 1700000000UL;
    }

    if (!timeSynced) {
      Serial.println("NTP not synced; skip Firebase send.");
      lastReadingTime = now;
      return;
    }

    Serial.print("Vdc: ");
    Serial.print(PZEMVoltage);
    Serial.print(" V  Idc: ");
    Serial.print(PZEMCurrent);
    Serial.print(" A  Power: ");
    Serial.print(PZEMPower);
    Serial.print(" W  Energy: ");
    Serial.print(PZEMEnergy);
    Serial.println(" Wh");

    const unsigned long epoch = (unsigned long)timeClient.getEpochTime();

    FirebaseJson json;
    json.add("Voltage", PZEMVoltage);
    json.add("Current", PZEMCurrent);
    json.add("Power", PZEMPower);
    json.add("VoltagePV", PZEMVoltage);
    json.add("VoltageBattery", PZEMVoltage);   // single meter: same as PV
    json.add("SOC", 0);                        // no second meter for battery SOC
    json.add("PowerLampu", PZEMPower);
    json.add("EnergyPV", PZEMEnergy);
    json.add("timestamp", epoch);
    json.add("deviceId", settings.deviceId);

    String dataPath = "/devices/" + String(settings.deviceId) + "/data/" + String(epoch);

    if (Firebase.setJSON(fbdo, dataPath, json)) {
      Serial.println("Firebase: OK");

      String devicePath = "/devices/" + String(settings.deviceId);
      FirebaseJson deviceJson;
      deviceJson.add("lastSeen", (unsigned long)(epoch * 1000UL));
      deviceJson.add("lastSeenFormatted", timeClient.getFormattedTime());
      Firebase.updateNode(fbdo, devicePath, deviceJson);
    } else {
      Serial.println("Firebase FAIL: " + fbdo.errorReason());
    }

    lastReadingTime = now;
  }
}
