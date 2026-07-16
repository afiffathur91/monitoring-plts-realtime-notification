#include <ESP8266WiFi.h>
#include <FirebaseESP8266.h>
#include <NTPClient.h>
#include <WiFiUdp.h>
#include <ArduinoJson.h>

// Firebase Credentials
#define FIREBASE_HOST "mobile-plts-afif-default-rtdb.asia-southeast1.firebasedatabase.app"  // Without http:// or https://
#define FIREBASE_AUTH "rEBGZiO682aPbrKfZy6JT8kl20NgrWgI0724ZY5w"
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"

// Pin definitions for sensors
const int VOLTAGE_PIN = A0;  // Analog pin for voltage sensor
const int CURRENT_PIN = A0;  // Using A0 since ESP8266 only has one ADC pin

// Constants for measurement
const unsigned long MEASUREMENT_INTERVAL = 5000;  // Read every 5 seconds

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

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  
  // Set pin modes
  pinMode(VOLTAGE_PIN, INPUT);
  pinMode(CURRENT_PIN, INPUT);
  
  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());

  // Initialize time client
  timeClient.begin();
  timeClient.setTimeOffset(25200); // GMT+7 for Indonesia (7 * 3600)
  
  // Initialize Firebase
  config.database_url = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  if (WiFi.status() == WL_CONNECTED && Firebase.ready()) {
    unsigned long currentTime = millis();
    
    // Check if it's time to take a reading
    if (currentTime - lastReadingTime >= READ_INTERVAL) {
      // Update NTP time
      timeClient.update();
      
      // Read sensor values
      int voltageRaw = analogRead(VOLTAGE_PIN);
      int currentRaw = analogRead(CURRENT_PIN);
      
      // Convert to actual values
      float voltage = voltageRaw * VOLTAGE_FACTOR;
      float current = currentRaw * CURRENT_FACTOR;
      float power = voltage * current;
      
      // Create Firebase JSON object
      FirebaseJson json;
      json.add("voltage", voltage);
      json.add("current", current);
      json.add("power", power);
      json.add("timestamp", timeClient.getEpochTime());
      
      // Generate unique key based on timestamp
      String dataPath = "/sensor/" + String(timeClient.getEpochTime());
      
      // Send to Firebase
      if (Firebase.setJSON(fbdo, dataPath, json)) {
        Serial.println("Data sent to Firebase successfully");
        Serial.printf("Path: %s\n", dataPath.c_str());
      } else {
        Serial.println("Failed to send data to Firebase");
        Serial.println("Reason: " + fbdo.errorReason());
      }
      
      lastReadingTime = currentTime;
    }
  }
}