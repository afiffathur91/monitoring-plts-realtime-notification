#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <ArduinoJson.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <ESP8266WebServer.h>
#include <DNSServer.h>
#include <EEPROM.h>

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

// Pin definitions for sensors
const int VOLTAGE_PIN = A0;  // Analog pin for voltage sensor
const int CURRENT_PIN = A0;  // ESP8266 only has one analog pin (A0)

// Digital pins for multiplexing (optional)
const int MUX_SELECT = D1;  // Digital pin to select between voltage/current reading

// Calibration values
const float VOLTAGE_FACTOR = 0.0048828125;  // 5V / 1024 steps
const float CURRENT_FACTOR = 0.0048828125;  // Adjust based on your sensor

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// NTP untuk timestamp
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org");

// Timing
unsigned long lastReadingTime = 0;
const unsigned long READ_INTERVAL = 5000;  // Read every 5 seconds

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

  // Set pin modes
  pinMode(VOLTAGE_PIN, INPUT);
  pinMode(MUX_SELECT, OUTPUT);
  Serial.println("Pin modes configured");

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
  timeClient.setTimeOffset(25200); // GMT+7 for Indonesia (7 * 3600)
  
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
    unsigned long currentTime = millis();
    
    // Check if it's time to take a reading
    if (currentTime - lastReadingTime >= READ_INTERVAL) {
      // Update NTP time
      timeClient.update();
      
      // Read voltage sensor
      digitalWrite(MUX_SELECT, LOW);  // Select voltage sensor
      delay(10);  // Allow settling time
      int voltageRaw = analogRead(VOLTAGE_PIN);
      
      // Read current sensor
      digitalWrite(MUX_SELECT, HIGH);  // Select current sensor
      delay(10);  // Allow settling time
      int currentRaw = analogRead(VOLTAGE_PIN);  // Using same pin since ESP8266 only has one ADC
      
      // Convert to actual values
      float voltage = voltageRaw * VOLTAGE_FACTOR;
      float current = currentRaw * CURRENT_FACTOR;
      float power = voltage * current;
      
      // Debug print sensor readings
      Serial.println("\nSensor Readings:");
      Serial.printf("Raw Voltage: %d, Voltage: %.2f V\n", voltageRaw, voltage);
      Serial.printf("Raw Current: %d, Current: %.2f A\n", currentRaw, current);
      Serial.printf("Power: %.2f W\n", power);
      
      // Create Firebase JSON object
      FirebaseJson json;
      json.add("Voltage", voltage);
      json.add("Current", current);
      json.add("Power", power);
      json.add("timestamp", timeClient.getEpochTime());
      json.add("deviceId", settings.deviceId);
      
      // Generate path with device ID
      String dataPath = "/devices/" + String(settings.deviceId) + "/data/" + String(timeClient.getEpochTime());
      
      // Send to Firebase
      if (Firebase.setJSON(fbdo, dataPath, json)) {
        Serial.println("Data sent to Firebase successfully");
        Serial.printf("Path: %s\n", dataPath.c_str());
        
        // Also update device metadata with lastSeen timestamp
        String devicePath = "/devices/" + String(settings.deviceId);
        FirebaseJson deviceJson;
        deviceJson.add("lastSeen", timeClient.getEpochTime() * 1000); // milliseconds for Flutter
        deviceJson.add("lastSeenFormatted", timeClient.getFormattedTime());
        Firebase.updateNode(fbdo, devicePath, deviceJson);
      } else {
        Serial.println("Failed to send data to Firebase");
        Serial.println("Reason: " + fbdo.errorReason());
      }
      
      lastReadingTime = currentTime;
    }
  }
}