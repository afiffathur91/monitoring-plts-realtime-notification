#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <ArduinoJson.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <ESP8266WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>
#include <math.h>
#include <SoftwareSerial.h>
#include <ModbusMaster.h>

// Access Point settings
const char* AP_SSID = "PLTS_Monitor_AP";  // Nama WiFi yang akan dibuat ESP8266
const byte DNS_PORT = 53;
IPAddress apIP(192, 168, 4, 1);
DNSServer dnsServer;
ESP8266WebServer webServer(80);

// Struct untuk menyimpan kredensial WiFi
struct Settings {
  char ssid[32];
  char password[64];
  char deviceId[32];
  bool configured;
} settings;

// Konfigurasi Firebase
#define FIREBASE_HOST "mobile-plts-afif-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "rEBGZiO682aPbrKfZy6JT8kl20NgrWgI0724ZY5w"

// Software Serial for PZEM communication
SoftwareSerial PZEMSerial;

// Modbus configuration for PZEM meters
static uint8_t pzemSlaveAddr = 0x01;    // Address of PZEM meter 1 (PV)
static uint8_t pzemSlaveAddr2 = 0x02;   // Address of PZEM meter 2 (Battery)
static uint16_t NewshuntAddr = 0x0001;  // External shunt value for DC Meter (0x0001 = 50A)
static uint16_t NewshuntAddr2 = 0x0001;
ModbusMaster node;   // For PV meter
ModbusMaster node2;  // For Battery meter

// PZEM Meter 1 (PV) readings
float PZEMVoltage = 0;   // PV Voltage
float PZEMCurrent = 0;   // PV Current
float PZEMPower = 0;     // PV Power
float PZEMEnergy = 0;    // PV Energy

// PZEM Meter 2 (Battery) readings
float PZEMVoltage2 = 0;  // Battery Voltage
float PZEMCurrent2 = 0;  // Battery Current
float PZEMPower2 = 0;    // Battery Power
float PZEMEnergy2 = 0;   // Battery Energy

// Battery parameters for SOC calculation
const float battery_max = 3.65;  // Maximum voltage of battery (100% SOC)
const float battery_min = 2.60;  // Minimum voltage of battery (0% SOC)
int vPersen = 0;  // SOC percentage

// Timing variables
unsigned long startMillisPZEM = 0;
unsigned long currentMillisPZEM = 0;
const unsigned long periodPZEM = 500;  // Read PZEM every 500ms

unsigned long lastReadingTime = 0;
const unsigned long READ_INTERVAL = 5000;  // Send to Firebase every 5 seconds

int a = 0;  // Flag to alternate between meter 1 and meter 2

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// NTP untuk timestamp
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "id.pool.ntp.org");
bool timeSynced = false;

// Halaman web untuk konfigurasi
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
    // EEPROM not initialized - set defaults
    memset(&settings, 0, sizeof(settings));
    settings.configured = false;
    // write defaults so next boot sees initialized EEPROM
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
  // Debug info
  Serial.print("Started AP: ");
  Serial.println(AP_SSID);
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  dnsServer.start(DNS_PORT, "*", apIP);

  webServer.on("/", HTTP_GET, []() {
    webServer.send(200, "text/html", configHTML);
  });

  webServer.on("/save", HTTP_POST, []() {
    String deviceId = webServer.arg("deviceid");
    String ssid = webServer.arg("ssid");
    String password = webServer.arg("password");

    // Validasi input
    if (deviceId.length() == 0 || ssid.length() == 0) {
      webServer.send(400, "text/plain", "Device ID and WiFi Name are required");
      return;
    }

    // Coba koneksi ke WiFi terlebih dahulu
    WiFi.begin(ssid.c_str(), password.c_str());
    Serial.print("\nTesting WiFi connection to: ");
    Serial.println(ssid);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 10) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\nFailed to connect to WiFi during testing");
      webServer.send(400, "text/plain", "Could not connect to the specified WiFi network. Please check SSID and password.");
      WiFi.disconnect();
      return;
    }

    // Jika koneksi berhasil, simpan settings
    Serial.println("\nWiFi test successful, saving settings...");
    deviceId.toCharArray(settings.deviceId, sizeof(settings.deviceId));
    ssid.toCharArray(settings.ssid, sizeof(settings.ssid));
    password.toCharArray(settings.password, sizeof(settings.password));
    settings.configured = true;

    saveSettings();

    String response = "Settings saved successfully. Device is connected to WiFi and will start monitoring. "
                     "Device ID: " + deviceId + "\n"
                     "WiFi: " + ssid + "\n"
                     "IP Address: " + WiFi.localIP().toString();
                     
    webServer.send(200, "text/plain", response);
    
    // Tunggu response terkirim
    delay(1000);
    
    // Stop AP mode dan services yang tidak diperlukan
    dnsServer.stop();
    webServer.stop();
    WiFi.softAPdisconnect(true);
    
    // Langsung mulai monitoring tanpa restart
    Serial.println("Starting monitoring mode...");
  });

  webServer.begin();
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\nStarting PLTS Monitoring System");
  Serial.println("-------------------------------");

  // Initialize Software Serial for PZEM communication
  // GPIO 4 (D2) = Rx/RO, GPIO 0 (D3) = Tx/DI
  PZEMSerial.begin(9600, SWSERIAL_8N2, 4, 0);
  Serial.println("PZEM Serial initialized");

  // Load saved settings
  loadSettings();

  // If not configured, start AP mode for configuration
  if (!settings.configured) {
    Serial.println("No configuration found. Starting setup AP...");
    setupAccessPoint();
    return;
  }

  // Connect to WiFi with saved credentials
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
    Serial.println("\nFailed to connect. Starting setup AP...");
    settings.configured = false;
    saveSettings();
    ESP.restart();
    return;
  }

  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());

  // Initialize time client
  timeClient.begin();
  // IMPORTANT: Keep epoch time in UTC (offset 0). Flutter will convert to local time.
  timeClient.setTimeOffset(0);

  // Force NTP sync so we don't get 1970 timestamps.
  // If NTP can't sync, we will avoid sending data until it does.
  Serial.println("Syncing NTP time...");
  for (int i = 0; i < 10; i++) {
    if (timeClient.update()) break;
    timeClient.forceUpdate();
    delay(500);
  }
  timeSynced = timeClient.getEpochTime() > 1700000000UL; // sanity check (>= ~2023)
  Serial.printf("NTP synced: %s, epoch=%lu\n", timeSynced ? "YES" : "NO", (unsigned long)timeClient.getEpochTime());
  
  // Initialize Firebase with reconnection handling
  config.database_url = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  
  // Firebase.begin returns void in this library version; call it once then wait for readiness
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  int fbAttempts = 0;
  while (!Firebase.ready() && fbAttempts < 3) {
    Serial.println("Waiting for Firebase token...");
    delay(1000);
    fbAttempts++;
  }

  if (!Firebase.ready()) {
    Serial.println("Failed to initialize Firebase after 3 attempts");
    settings.configured = false;
    saveSettings();
    ESP.restart();
    return;
  }

  Serial.println("Firebase connection successful");
  
  // Initialize timing
  startMillisPZEM = millis();
  lastReadingTime = millis();
}

void loop() {
  // If not configured, handle AP mode
  if (!settings.configured) {
    dnsServer.processNextRequest();
    webServer.handleClient();
    return;
  }

  // Normal operation mode
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    currentMillisPZEM = millis();
    
    // Read PZEM meters alternately
    if (a == 0) {
      // Read Meter 1 (PV)
      node.begin(pzemSlaveAddr, PZEMSerial);
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
        a = 1;
        startMillisPZEM = currentMillisPZEM;
      }
    } else {
      // Read Meter 2 (Battery)
      node2.begin(pzemSlaveAddr2, PZEMSerial);
      if (currentMillisPZEM - startMillisPZEM >= periodPZEM) {
        uint8_t result2 = node2.readInputRegisters(0x0000, 6);
        if (result2 == node2.ku8MBSuccess) {
          uint32_t tempdouble2 = 0x00000000;
          PZEMVoltage2 = node2.getResponseBuffer(0x0000) / 100.0;
          PZEMCurrent2 = node2.getResponseBuffer(0x0001) / 100.0;
          tempdouble2 = (node2.getResponseBuffer(0x0003) << 16) + node2.getResponseBuffer(0x0002);
          PZEMPower2 = tempdouble2 / 10.0;
          tempdouble2 = (node2.getResponseBuffer(0x0005) << 16) + node2.getResponseBuffer(0x0004);
          PZEMEnergy2 = tempdouble2;
          
          // Calculate SOC from battery voltage
          vPersen = ((PZEMVoltage2 - battery_min) / (battery_max - battery_min)) * 100;
          if (vPersen <= 0) {
            vPersen = 0;
          } else if (vPersen >= 100) {
            vPersen = 100;
          }
        }
        a = 0;
        startMillisPZEM = currentMillisPZEM;
      }
    }
    
    // Send data to Firebase every READ_INTERVAL
    unsigned long currentTime = millis();
    if (currentTime - lastReadingTime >= READ_INTERVAL) {
      // Update NTP time
      if (!timeClient.update()) {
        timeClient.forceUpdate();
      }
      if (!timeSynced) {
        timeSynced = timeClient.getEpochTime() > 1700000000UL;
      }

      // If time isn't synced yet, skip sending to avoid wrong timestamps (1970).
      if (!timeSynced) {
        Serial.println("NTP not synced yet; skipping Firebase send to avoid wrong timestamps.");
        lastReadingTime = currentTime;
        return;
      }
      
      // Debug print sensor readings
      Serial.println("\n=== Sensor Readings ===");
      Serial.println("Energy Meter 1 (PV):");
      Serial.printf("  Voltage: %.2f V\n", PZEMVoltage);
      Serial.printf("  Current: %.2f A\n", PZEMCurrent);
      Serial.printf("  Power: %.2f W\n", PZEMPower);
      Serial.printf("  Energy: %.0f Wh\n", PZEMEnergy);
      
      Serial.println("Energy Meter 2 (Battery):");
      Serial.printf("  Voltage: %.2f V\n", PZEMVoltage2);
      Serial.printf("  Current: %.2f A\n", PZEMCurrent2);
      Serial.printf("  Power: %.2f W\n", PZEMPower2);
      Serial.printf("  Energy: %.0f Wh\n", PZEMEnergy2);
      Serial.printf("  SOC: %d%%\n", vPersen);
      Serial.printf("Time: %s\n", timeClient.getFormattedTime().c_str());
      
      // Create Firebase JSON object with all required fields
      FirebaseJson json;
      
      // Main fields (for compatibility)
      json.add("Voltage", PZEMVoltage);  // PV Voltage as main voltage
      json.add("Current", PZEMCurrent);  // PV Current as main current
      json.add("Power", PZEMPower);      // PV Power as main power
      
      // Additional fields for UI
      json.add("VoltagePV", PZEMVoltage);           // VOLT PV
      json.add("VoltageBattery", PZEMVoltage2);     // TEGANGAN BATERAI
      json.add("SOC", (float)vPersen);              // SOC BATERAI (%)
      json.add("PowerLampu", PZEMPower2);           // Watt Lampu (using battery power as lamp power)
      
      // Additional data
      json.add("CurrentPV", PZEMCurrent);
      json.add("CurrentBattery", PZEMCurrent2);
      json.add("PowerPV", PZEMPower);
      json.add("PowerBattery", PZEMPower2);
      json.add("EnergyPV", PZEMEnergy);
      json.add("EnergyBattery", PZEMEnergy2);
      
      const unsigned long epoch = (unsigned long)timeClient.getEpochTime(); // seconds UTC
      json.add("timestamp", epoch);
      json.add("deviceId", settings.deviceId);
      
      // Generate path with device ID
      String dataPath = "/devices/" + String(settings.deviceId) + "/data/" + String(epoch);
      
      // Send to Firebase
      if (Firebase.setJSON(fbdo, dataPath, json)) {
        Serial.println("Data sent to Firebase successfully");
        Serial.printf("Path: %s\n", dataPath.c_str());
        
        // Also update device metadata with lastSeen timestamp
        String devicePath = "/devices/" + String(settings.deviceId);
        FirebaseJson deviceJson;
        // Store lastSeen as milliseconds UTC
        deviceJson.add("lastSeen", (unsigned long)(epoch * 1000UL));
        deviceJson.add("lastSeenFormatted", timeClient.getFormattedTime()); // UTC HH:MM:SS
        Firebase.updateNode(fbdo, devicePath, deviceJson);
      } else {
        Serial.println("Failed to send data to Firebase");
        Serial.println("Reason: " + fbdo.errorReason());
      }
      
      lastReadingTime = currentTime;
    }
  }
}
