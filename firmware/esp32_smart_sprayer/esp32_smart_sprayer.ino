/*
 * ======================================================================================
 * ESP32 Smart Sprayer Firmware v2.0 (BLE + WiFi + MQTT + Real-Time Scheduler)
 * Designed for Pestzon Spray App
 * Repository: https://github.com/Ronaltama/PestzonSprayApps
 * ======================================================================================
 *
 * KRITERIA PIN:
 * - Relay / Modul Pompa : GPIO 23
 *
 * SPESIFIKASI BLE:
 * - Service UUID:       4fa1c691-e9a5-4307-9a45-500f7a6a0a9c
 * - RX Characteristic: 6e400002-b5a3-f393-e0a9-e50e24dcca9e (Write/Write Without Response)
 * - TX Characteristic: 6e400003-b5a3-f393-e0a9-e50e24dcca9e (Notify)
 *
 * ARSITEKTUR KOMUNIKASI:
 *   HP <-- BLE --> ESP32 <-- WiFi/MQTT --> Broker Cloud
 *
 * ALUR SETUP WiFi (SEKALI PROGRAM, SELEBIHNYA DARI APP):
 *   1. Hubungkan HP ke ESP32 via BLE
 *   2. Di App → Tab Cloud → isi SSID & Password → Kirim ke ESP32
 *   3. ESP32 terima command CONFIG, simpan SSID/PW ke NVS, konek WiFi
 *   4. Setelah WiFi konek, ESP32 otomatis konek ke MQTT broker
 *   5. Mulai sekarang bisa kontrol juga dari cloud (MQTT)!
 *
 * DEPENDENCIES ARDUINO IDE:
 *   1. ESP32 Board Package (by Espressif Systems) — via Board Manager
 *   2. ArduinoJson Library (v6 atau v7)           — via Library Manager
 *   3. PubSubClient Library (by Nick O'Leary)     — via Library Manager
 * ======================================================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <WiFi.h>
#include <PubSubClient.h>

// --------------------------------------------------------------------------------------
// HARDWARE CONFIGURATION
// --------------------------------------------------------------------------------------
#define PUMP_PIN          23      // Pin Relay Pompa
#define LED_PIN           4       // Pin Lampu Malam (otomatis)
#define RELAY_ACTIVE_LOW  false   // Ubah ke true jika relay Anda Active-LOW

// Nominal Debit Pompa (ml/detik) — default 15.0 ml/s, bisa dikalibrasi dari App
float flowRateMlPerSec = 15.0;

// --------------------------------------------------------------------------------------
// BLE UUIDS — Kontrak FetCoreApp
// --------------------------------------------------------------------------------------
#define SERVICE_UUID           "4fa1c691-e9a5-4307-9a45-500f7a6a0a9c"
#define CHARACTERISTIC_UUID_RX "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_UUID_TX "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// --------------------------------------------------------------------------------------
// MQTT CONFIGURATION
// --------------------------------------------------------------------------------------
#define MQTT_BROKER      "broker.emqx.io"   // Broker publik (bisa diubah via App)
#define MQTT_PORT        1883
#define MQTT_CLIENT_ID   "esp32_sprayer"     // Akan diganti dengan deviceId dari App

// Topic MQTT — harus sama dengan yang dipakai MqttService Flutter
String mqttDeviceId    = "esp_sprayer";
String topicCommand    = "";  // pestzon/<deviceId>/cmd
String topicStatus     = "";  // pestzon/<deviceId>/status
String topicLog        = "";  // pestzon/<deviceId>/log
String topicResponse   = "";  // pestzon/<deviceId>/response

// --------------------------------------------------------------------------------------
// DATA STRUCTURES & GLOBALS
// --------------------------------------------------------------------------------------
struct Schedule {
  int   id;
  int   hour;
  int   minute;
  int   duration;
  bool  active;
  bool  executedToday;
};

#define MAX_SCHEDULES 10
Schedule schedules[MAX_SCHEDULES];
int scheduleCount = 0;

Preferences preferences;

// BLE
BLEServer*         pServer           = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
bool deviceConnected = false;

// WiFi & MQTT clients
WiFiClient   espClient;
PubSubClient mqttClient(espClient);

// Status koneksi
bool wifiEnabled       = false;   // True jika sudah ada SSID/PW tersimpan
bool mqttConnected_    = false;

// Kredensial WiFi (disimpan NVS)
String wifiSsid     = "";
String wifiPassword = "";
String mqttBroker   = MQTT_BROKER;

// Status Operasional Pompa & Lampu
bool          isPumpRunning        = false;
unsigned long sprayStartTime       = 0;
unsigned long sprayTargetDurationMs = 0;
String        currentSprayMode     = "Manual";
bool          forceLedOn           = false; // Kontrol manual dari app

// Real-Time Clock Internal (Disinkronkan dari HP via BLE saat konek)
unsigned long lastTimeSyncMillis = 0;
int currentYear   = 2026;
int currentMonth  = 9;
int currentDay    = 6;
int currentHour   = 0;
int currentMinute = 0;
int currentSecond = 0;
bool isTimeSynced = false;

// Statistik Harian
int   totalSesiToday      = 0;
float totalVolumeTodayMl  = 0.0;

// Buffer BLE incoming
String rxBuffer = "";

// Timer reconnect WiFi & MQTT
unsigned long lastWifiRetryMs  = 0;
unsigned long lastMqttRetryMs  = 0;
#define WIFI_RETRY_INTERVAL  30000   // 30 detik
#define MQTT_RETRY_INTERVAL  10000   // 10 detik

// Forward Declarations
void sendSummary();
void sendSchedules();
void sendStats();
void sendAck(const char* cmd, const char* status);
void startSpray(int durationSeconds, const char* mode);
void stopSpray();
void publishMqttStatus();

// --------------------------------------------------------------------------------------
// HELPER: RELAY
// --------------------------------------------------------------------------------------
void setRelayState(bool turnOn) {
  if (turnOn) {
    digitalWrite(PUMP_PIN, RELAY_ACTIVE_LOW ? LOW : HIGH);
  } else {
    digitalWrite(PUMP_PIN, RELAY_ACTIVE_LOW ? HIGH : LOW);
  }
}

// --------------------------------------------------------------------------------------
// TIME KEEPING & SCHEDULE TRIGGER
// --------------------------------------------------------------------------------------
void syncTime(int year, int month, int day, int hour, int minute, int second) {
  if (year >= 2020) currentYear   = year;
  if (month >= 1 && month <= 12) currentMonth = month;
  if (day >= 1 && day <= 31)     currentDay   = day;
  currentHour   = hour;
  currentMinute = minute;
  currentSecond = second;
  lastTimeSyncMillis = millis();
  isTimeSynced = true;
  Serial.printf("ESP32 Jam Disinkronkan: %04d-%02d-%02d %02d:%02d:%02d WIB\n",
                currentYear, currentMonth, currentDay, hour, minute, second);
}

void updateInternalTime() {
  if (!isTimeSynced) return;

  unsigned long now     = millis();
  unsigned long elapsed = (now - lastTimeSyncMillis) / 1000;
  if (elapsed >= 1) {
    lastTimeSyncMillis += elapsed * 1000;
    currentSecond += elapsed;

    while (currentSecond >= 60) {
      currentSecond -= 60;
      currentMinute++;
      if (currentMinute >= 60) {
        currentMinute -= 60;
        currentHour = (currentHour + 1) % 24;
        if (currentHour == 0) {
          currentDay++;
          for (int i = 0; i < scheduleCount; i++) {
            schedules[i].executedToday = false;
          }
          // Reset statistik harian di tengah malam
          totalSesiToday     = 0;
          totalVolumeTodayMl = 0.0;
        }
      }
    }
  }
}

void checkSchedules() {
  if (!isTimeSynced || isPumpRunning) return;

  for (int i = 0; i < scheduleCount; i++) {
    if (schedules[i].active && !schedules[i].executedToday) {
      if (schedules[i].hour == currentHour && schedules[i].minute == currentMinute) {
        schedules[i].executedToday = true;
        Serial.printf("[JADWAL TRIGGERED!] Jam %02d:%02d - Durasi %ds (PIN 23 ON)\n",
                      schedules[i].hour, schedules[i].minute, schedules[i].duration);
        startSpray(schedules[i].duration, "Otomatis");
        break;
      }
    }
  }
}

// --------------------------------------------------------------------------------------
// BLE NOTIFY TRANSMITTER (20-BYTE CHUNKING UNTUK ATT MTU BLE)
// --------------------------------------------------------------------------------------
void sendBleJson(const JsonDocument& doc) {
  if (!deviceConnected || pTxCharacteristic == NULL) return;

  String output;
  serializeJson(doc, output);
  output += "\n";

  size_t len = output.length();
  size_t pos = 0;
  while (pos < len) {
    size_t chunkSize = (len - pos > 20) ? 20 : (len - pos);
    pTxCharacteristic->setValue((uint8_t*)(output.c_str() + pos), chunkSize);
    pTxCharacteristic->notify();
    pos += chunkSize;
    delay(15);
  }
  Serial.print("BLE Sent: ");
  Serial.print(output);
}

// --------------------------------------------------------------------------------------
// MQTT PUBLISH HELPER
// --------------------------------------------------------------------------------------
void publishMqttJson(const String& topic, const JsonDocument& doc) {
  if (!mqttConnected_) return;
  String output;
  serializeJson(doc, output);
  mqttClient.publish(topic.c_str(), output.c_str(), false);
  Serial.print("MQTT Published to ");
  Serial.print(topic);
  Serial.print(": ");
  Serial.println(output);
}

/// Kirim ke BLE (jika ada client) DAN ke MQTT (jika konek).
void sendJsonBoth(const JsonDocument& doc) {
  sendBleJson(doc);
  if (!topicResponse.isEmpty()) {
    publishMqttJson(topicResponse, doc);
  }
}

// --------------------------------------------------------------------------------------
// LOG STORAGE & HISTORY (NVS)
// --------------------------------------------------------------------------------------
struct LogEntry {
  int   durationSec;
  float volumeMl;
  char  mode[16];
  char  timestamp[25];
};

#define MAX_LOGS 10
LogEntry logHistory[MAX_LOGS];
int logHistoryCount = 0;

void saveLogsToNvs() {
  preferences.begin("sprayer_logs", false);
  preferences.putInt("log_count", logHistoryCount);
  for (int i = 0; i < logHistoryCount; i++) {
    String prefix = "l_" + String(i) + "_";
    preferences.putInt((prefix + "d").c_str(), logHistory[i].durationSec);
    preferences.putFloat((prefix + "v").c_str(), logHistory[i].volumeMl);
    preferences.putString((prefix + "m").c_str(), logHistory[i].mode);
    preferences.putString((prefix + "t").c_str(), logHistory[i].timestamp);
  }
  preferences.end();
}

void loadLogsFromNvs() {
  preferences.begin("sprayer_logs", true);
  logHistoryCount = preferences.getInt("log_count", 0);
  if (logHistoryCount > MAX_LOGS) logHistoryCount = MAX_LOGS;
  for (int i = 0; i < logHistoryCount; i++) {
    String prefix = "l_" + String(i) + "_";
    logHistory[i].durationSec = preferences.getInt((prefix + "d").c_str(), 0);
    logHistory[i].volumeMl    = preferences.getFloat((prefix + "v").c_str(), 0.0);
    String m = preferences.getString((prefix + "m").c_str(), "Manual");
    strncpy(logHistory[i].mode, m.c_str(), sizeof(logHistory[i].mode) - 1);
    String t = preferences.getString((prefix + "t").c_str(), "");
    strncpy(logHistory[i].timestamp, t.c_str(), sizeof(logHistory[i].timestamp) - 1);
  }
  preferences.end();
}

void addLogEntry(int durationSec, float volumeMl, const char* mode) {
  if (logHistoryCount >= MAX_LOGS) {
    for (int i = 0; i < MAX_LOGS - 1; i++) logHistory[i] = logHistory[i + 1];
    logHistoryCount = MAX_LOGS - 1;
  }
  logHistory[logHistoryCount].durationSec = durationSec;
  logHistory[logHistoryCount].volumeMl    = volumeMl;
  strncpy(logHistory[logHistoryCount].mode, mode, sizeof(logHistory[logHistoryCount].mode) - 1);

  char tsBuf[25];
  snprintf(tsBuf, sizeof(tsBuf), "%04d-%02d-%02dT%02d:%02d:%02d",
           currentYear, currentMonth, currentDay, currentHour, currentMinute, currentSecond);
  strncpy(logHistory[logHistoryCount].timestamp, tsBuf, sizeof(logHistory[logHistoryCount].timestamp) - 1);

  logHistoryCount++;
  saveLogsToNvs();
}

void sendLog(int durationSec, float volumeMl, const char* mode, const char* timestampStr = NULL) {
  StaticJsonDocument<300> doc;
  doc["t"] = "log";
  if (timestampStr != NULL && strlen(timestampStr) > 0) {
    doc["timestamp"] = timestampStr;
  } else {
    char tsBuf[25];
    snprintf(tsBuf, sizeof(tsBuf), "%04d-%02d-%02dT%02d:%02d:%02d",
             currentYear, currentMonth, currentDay, currentHour, currentMinute, currentSecond);
    doc["timestamp"] = tsBuf;
  }
  doc["durationSeconds"] = durationSec;
  doc["volumeMl"]        = volumeMl;
  doc["batteryPercentage"] = 0;
  doc["isSolarCharging"]   = 0;
  doc["mode"]   = mode;
  doc["status"] = "Sukses";
  doc["communicationMethod"] = deviceConnected ? "BLE" : "MQTT";

  sendBleJson(doc);

  // Publish log ke topic khusus MQTT
  if (mqttConnected_ && !topicLog.isEmpty()) {
    publishMqttJson(topicLog, doc);
  }
}

void sendLogHistory() {
  for (int i = 0; i < logHistoryCount; i++) {
    sendLog(logHistory[i].durationSec, logHistory[i].volumeMl,
            logHistory[i].mode, logHistory[i].timestamp);
    delay(30);
  }
}

// --------------------------------------------------------------------------------------
// PREFERENCES / NVS — CALIBRATION, SCHEDULES, WIFI CONFIG
// --------------------------------------------------------------------------------------
void saveCalibrationToNvs() {
  preferences.begin("sprayer", false);
  preferences.putFloat("flow_rate", flowRateMlPerSec);
  preferences.end();
  Serial.printf("Kalibrasi tersimpan ke Flash NVS: %.2f ml/s\n", flowRateMlPerSec);
}

void loadCalibrationFromNvs() {
  preferences.begin("sprayer", true);
  flowRateMlPerSec = preferences.getFloat("flow_rate", 15.0);
  if (flowRateMlPerSec <= 0.1) flowRateMlPerSec = 15.0;
  preferences.end();
  Serial.printf("Loaded flow rate from Flash NVS: %.2f ml/s\n", flowRateMlPerSec);
}

void saveSchedulesToNvs() {
  preferences.begin("sprayer", false);
  preferences.putInt("sched_count", scheduleCount);
  for (int i = 0; i < scheduleCount; i++) {
    String prefix = "s_" + String(i) + "_";
    preferences.putInt((prefix + "id").c_str(), schedules[i].id);
    preferences.putInt((prefix + "h").c_str(),  schedules[i].hour);
    preferences.putInt((prefix + "m").c_str(),  schedules[i].minute);
    preferences.putInt((prefix + "d").c_str(),  schedules[i].duration);
    preferences.putBool((prefix + "a").c_str(), schedules[i].active);
  }
  preferences.end();
  Serial.printf("Tersimpan %d jadwal ke Flash NVS.\n", scheduleCount);
}

void loadSchedulesFromNvs() {
  preferences.begin("sprayer", true);
  scheduleCount = preferences.getInt("sched_count", 0);
  if (scheduleCount > MAX_SCHEDULES) scheduleCount = MAX_SCHEDULES;
  for (int i = 0; i < scheduleCount; i++) {
    String prefix = "s_" + String(i) + "_";
    schedules[i].id       = preferences.getInt((prefix + "id").c_str(), i + 1);
    schedules[i].hour     = preferences.getInt((prefix + "h").c_str(), 7);
    schedules[i].minute   = preferences.getInt((prefix + "m").c_str(), 0);
    schedules[i].duration = preferences.getInt((prefix + "d").c_str(), 10);
    schedules[i].active   = preferences.getBool((prefix + "a").c_str(), true);
    schedules[i].executedToday = false;
  }
  preferences.end();
  Serial.printf("Loaded %d schedules from Flash NVS.\n", scheduleCount);
}

void saveWifiConfigToNvs() {
  preferences.begin("wifi_cfg", false);
  preferences.putString("ssid",   wifiSsid);
  preferences.putString("pw",     wifiPassword);
  preferences.putString("broker", mqttBroker);
  preferences.putString("dev_id", mqttDeviceId);
  preferences.end();
  Serial.println("WiFi config tersimpan ke NVS.");
}

void loadWifiConfigFromNvs() {
  preferences.begin("wifi_cfg", true);
  wifiSsid      = preferences.getString("ssid",   "");
  wifiPassword  = preferences.getString("pw",     "");
  mqttBroker    = preferences.getString("broker", MQTT_BROKER);
  mqttDeviceId  = preferences.getString("dev_id", "esp_sprayer");
  preferences.end();

  if (wifiSsid.length() > 0) {
    wifiEnabled = true;
    // Rebuild topic strings setelah load
    topicCommand  = "pestzon/" + mqttDeviceId + "/cmd";
    topicStatus   = "pestzon/" + mqttDeviceId + "/status";
    topicLog      = "pestzon/" + mqttDeviceId + "/log";
    topicResponse = "pestzon/" + mqttDeviceId + "/response";
    Serial.printf("Loaded WiFi config — SSID: %s, Broker: %s, DevId: %s\n",
                  wifiSsid.c_str(), mqttBroker.c_str(), mqttDeviceId.c_str());
  } else {
    Serial.println("Tidak ada WiFi config di NVS. BLE-only mode.");
  }
}

// --------------------------------------------------------------------------------------
// WIFI CONNECTION
// --------------------------------------------------------------------------------------
void connectWifi() {
  if (!wifiEnabled || wifiSsid.length() == 0) return;

  Serial.printf("Mencoba konek WiFi ke SSID: %s ... (Non-blocking)\n", wifiSsid.c_str());
  WiFi.disconnect();
  WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());
  
  lastWifiRetryMs = millis();
}

void maintainWifi() {
  if (!wifiEnabled) return;
  static bool wasConnected = false;

  if (WiFi.status() != WL_CONNECTED) {
    if (wasConnected) {
      wasConnected = false;
      Serial.println("[WiFi] Koneksi terputus.");
    }
    if (millis() - lastWifiRetryMs > WIFI_RETRY_INTERVAL) {
      lastWifiRetryMs = millis();
      Serial.println("[WiFi] Reconnecting...");
      WiFi.disconnect();
      WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());
    }
  } else {
    if (!wasConnected) {
      wasConnected = true;
      Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    }
  }
}

// --------------------------------------------------------------------------------------
// MQTT FUNCTIONS
// --------------------------------------------------------------------------------------
void updateMqttTopics() {
  topicCommand  = "pestzon/" + mqttDeviceId + "/cmd";
  topicStatus   = "pestzon/" + mqttDeviceId + "/status";
  topicLog      = "pestzon/" + mqttDeviceId + "/log";
  topicResponse = "pestzon/" + mqttDeviceId + "/response";
}

/// Callback MQTT saat ada pesan masuk dari broker
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.print("MQTT Received [");
  Serial.print(topic);
  Serial.print("]: ");
  Serial.println(msg);
  processCommandJson(msg);
}

void connectMqtt() {
  if (!wifiEnabled || WiFi.status() != WL_CONNECTED) return;
  if (mqttConnected_) return;

  mqttClient.setServer(mqttBroker.c_str(), MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  mqttClient.setKeepAlive(60);
  mqttClient.setSocketTimeout(10);

  String clientId = "pestzon_" + mqttDeviceId + "_" + String(millis());
  Serial.printf("[MQTT] Mencoba konek ke %s:%d sebagai %s ...\n",
                mqttBroker.c_str(), MQTT_PORT, clientId.c_str());

  if (mqttClient.connect(clientId.c_str())) {
    mqttConnected_ = true;
    Serial.println("[MQTT] Terhubung!");
    // Subscribe ke topic command agar bisa terima perintah dari app cloud
    mqttClient.subscribe(topicCommand.c_str());
    Serial.printf("[MQTT] Subscribed to: %s\n", topicCommand.c_str());
    // Langsung publish status online
    publishMqttStatus();
  } else {
    mqttConnected_ = false;
    Serial.printf("[MQTT] Gagal konek. State: %d. Coba ulang nanti...\n", mqttClient.state());
  }
}

void maintainMqtt() {
  if (!wifiEnabled) return;
  if (WiFi.status() != WL_CONNECTED) return;

  if (!mqttClient.connected()) {
    if (mqttConnected_) {
      mqttConnected_ = false;
      Serial.println("[MQTT] Koneksi terputus.");
    }
    if (millis() - lastMqttRetryMs > MQTT_RETRY_INTERVAL) {
      lastMqttRetryMs = millis();
      connectMqtt();
    }
  } else {
    mqttConnected_ = true;
    mqttClient.loop(); // Proses pesan masuk
  }
}

/// Publish status perangkat ke topicStatus (untuk monitoring real-time di App)
void publishMqttStatus() {
  if (!mqttConnected_) return;
  StaticJsonDocument<300> doc;
  doc["t"]            = "summary";
  doc["battery"]      = 0;
  doc["voltage"]      = 0.0;
  doc["isSolar"]      = 0;
  doc["isPumpRunning"] = isPumpRunning ? 1 : 0;
  doc["durationSec"]  = isPumpRunning ? (millis() - sprayStartTime) / 1000 : 0;
  doc["totalSesi"]    = totalSesiToday;
  doc["totalVolume"]  = totalVolumeTodayMl;
  doc["flowRate"]     = flowRateMlPerSec;
  doc["dailyTarget"]  = 1000.0;
  publishMqttJson(topicStatus, doc);
}

// --------------------------------------------------------------------------------------
// RESPONSE BUILDERS (BLE + MQTT dual publish)
// --------------------------------------------------------------------------------------
void sendSummary() {
  StaticJsonDocument<300> doc;
  doc["t"]             = "summary";
  doc["battery"]       = 0;
  doc["voltage"]       = 0.0;
  doc["isSolar"]       = 0;
  doc["isPumpRunning"] = isPumpRunning ? 1 : 0;
  doc["durationSec"]   = isPumpRunning ? (millis() - sprayStartTime) / 1000 : 0;
  doc["totalSesi"]     = totalSesiToday;
  doc["totalVolume"]   = totalVolumeTodayMl;
  doc["flowRate"]      = flowRateMlPerSec;
  doc["dailyTarget"]   = 1000.0;
  sendJsonBoth(doc);
}

void sendSchedules() {
  StaticJsonDocument<700> doc;
  doc["t"] = "schedules";
  JsonArray arr = doc.createNestedArray("schedules");
  for (int i = 0; i < scheduleCount; i++) {
    JsonObject obj = arr.createNestedObject();
    obj["id"]       = schedules[i].id;
    obj["hour"]     = schedules[i].hour;
    obj["minute"]   = schedules[i].minute;
    obj["duration"] = schedules[i].duration;
    obj["active"]   = schedules[i].active ? 1 : 0;
  }
  sendJsonBoth(doc);
}

void sendStats() {
  StaticJsonDocument<300> doc;
  doc["t"] = "stats";
  JsonArray days = doc.createNestedArray("days");
  JsonObject todayObj = days.createNestedObject();
  todayObj["date"]     = "Hari Ini";
  todayObj["volumeMl"] = totalVolumeTodayMl;
  sendJsonBoth(doc);
}

void sendAck(const char* cmd, const char* status) {
  StaticJsonDocument<200> doc;
  doc["t"]      = "ack";
  doc["ref"]    = cmd;
  doc["cmd"]    = cmd;
  doc["ok"]     = (strcmp(status, "ok") == 0 || strcmp(status, "1") == 0) ? 1 : 0;
  doc["status"] = status;
  sendJsonBoth(doc);
}

// --------------------------------------------------------------------------------------
// CONTROL FUNCTIONS
// --------------------------------------------------------------------------------------
void startSpray(int durationSeconds, const char* mode) {
  if (durationSeconds <= 0) return;
  isPumpRunning          = true;
  sprayStartTime         = millis();
  sprayTargetDurationMs  = (unsigned long)durationSeconds * 1000;
  currentSprayMode       = String(mode);
  setRelayState(true);
  Serial.printf("Pompa ON (PIN %d) selama %ds [Mode: %s]\n", PUMP_PIN, durationSeconds, mode);
  sendSummary();
  publishMqttStatus();
}

void stopSpray() {
  if (!isPumpRunning) { setRelayState(false); return; }
  setRelayState(false);
  unsigned long elapsedMs = millis() - sprayStartTime;
  int   elapsedSec = elapsedMs / 1000;
  float volumeMl   = elapsedSec * flowRateMlPerSec;

  isPumpRunning = false;
  totalSesiToday++;
  totalVolumeTodayMl += volumeMl;

  Serial.printf("Pompa OFF. Durasi: %ds, Volume: %.1f ml\n", elapsedSec, volumeMl);

  addLogEntry(elapsedSec, volumeMl, currentSprayMode.c_str());
  sendLog(elapsedSec, volumeMl, currentSprayMode.c_str());
  sendSummary();
  publishMqttStatus();
}

// --------------------------------------------------------------------------------------
// INCOMING COMMAND PARSER (BLE & MQTT unified handler)
// --------------------------------------------------------------------------------------
void processCommandJson(const String& jsonStr) {
  StaticJsonDocument<800> doc;
  DeserializationError err = deserializeJson(doc, jsonStr);
  if (err) {
    Serial.print("JSON Error: ");
    Serial.println(err.c_str());
    return;
  }

  // 1. Sinkronisasi Waktu (jika HP menyertakan field waktu)
  if (doc.containsKey("hour") && doc.containsKey("minute")) {
    int y   = doc["year"]   | 2026;
    int mon = doc["month"]  | 9;
    int d   = doc["day"]    | 6;
    int h   = doc["hour"]   | 0;
    int m   = doc["minute"] | 0;
    int s   = doc["second"] | 0;
    syncTime(y, mon, d, h, m, s);
  }

  // 2. Parse jenis command ("t", "cmd", atau "action")
  const char* typeKey = "";
  if (doc.containsKey("t"))      typeKey = doc["t"];
  else if (doc.containsKey("cmd"))    typeKey = doc["cmd"];
  else if (doc.containsKey("action")) typeKey = doc["action"];

  // 3. Handler per command type
  if (strcmp(typeKey, "get_summary") == 0) {
    sendSummary();
    sendLogHistory();
  }
  else if (strcmp(typeKey, "get_schedules") == 0) {
    sendSchedules();
  }
  else if (strcmp(typeKey, "get_stats") == 0) {
    sendStats();
  }
  else if (strcmp(typeKey, "get_logs") == 0) {
    sendLogHistory();
  }
  else if (strcmp(typeKey, "START") == 0 || strcmp(typeKey, "spray") == 0) {
    int         duration = doc["duration"] | 10;
    const char* mode     = doc["mode"]     | "Manual";
    startSpray(duration, mode);
  }
  else if (strcmp(typeKey, "STOP") == 0 || strcmp(typeKey, "stop") == 0) {
    stopSpray();
  }
  else if (strcmp(typeKey, "set_schedules")   == 0 ||
           strcmp(typeKey, "sync_schedule")    == 0 ||
           strcmp(typeKey, "sync_schedules")   == 0) {
    if (doc.containsKey("schedules")) {
      JsonArray arr   = doc["schedules"].as<JsonArray>();
      scheduleCount   = 0;
      for (JsonObject v : arr) {
        if (scheduleCount >= MAX_SCHEDULES) break;
        schedules[scheduleCount].id       = v["id"]       | (scheduleCount + 1);
        schedules[scheduleCount].hour     = v["hour"]     | 0;
        schedules[scheduleCount].minute   = v["minute"]   | 0;
        schedules[scheduleCount].duration = v["duration"] | (v["durationSeconds"] | 10);
        schedules[scheduleCount].active   = (v["active"]  | (v["isActive"] | 1)) == 1;
        schedules[scheduleCount].executedToday = false;
        scheduleCount++;
      }
      saveSchedulesToNvs();
      sendAck("sync_schedules", "ok");
      sendSchedules();
    }
  }
  else if (strcmp(typeKey, "set_calibration") == 0 ||
           strcmp(typeKey, "set_flow_rate")    == 0) {
    if (doc.containsKey("flowRate")) {
      flowRateMlPerSec = doc["flowRate"].as<float>();
      if (flowRateMlPerSec <= 0.1) flowRateMlPerSec = 15.0;
      saveCalibrationToNvs();
      sendAck("set_calibration", "ok");
      sendSummary();
    }
  }
  // ★ BARU: handler CONFIG — terima SSID/PW dari App, simpan ke NVS, konek WiFi
  else if (strcmp(typeKey, "CONFIG") == 0 ||
           strcmp(typeKey, "set_wifi")  == 0) {
    if (doc.containsKey("ssid")) {
      wifiSsid     = doc["ssid"].as<String>();
      wifiPassword = doc["password"].as<String>();
      if (doc.containsKey("mqtt_broker")) {
        mqttBroker = doc["mqtt_broker"].as<String>();
      }
      if (doc.containsKey("device_id")) {
        mqttDeviceId = doc["device_id"].as<String>();
      }
      wifiEnabled = true;
      updateMqttTopics();
      saveWifiConfigToNvs();
      sendAck("set_wifi", "ok");
      Serial.printf("CONFIG diterima. SSID=%s, akan konek WiFi...\n", wifiSsid.c_str());
      // Mulai konek WiFi secara non-blocking
      connectWifi();
      // Lanjut konek MQTT akan otomatis di-handle oleh maintainMqtt() di dalam loop()
      // begitu status WiFi.status() == WL_CONNECTED
    }
  }
  // ★ BARU: handler toggle_led — nyalakan/matikan lampu LED secara manual
  else if (strcmp(typeKey, "toggle_led") == 0) {
    if (doc.containsKey("state")) {
      forceLedOn = doc["state"].as<bool>();
      sendAck("toggle_led", "ok");
      Serial.printf("Lampu LED manual diubah menjadi: %s\n", forceLedOn ? "ON" : "OFF");
    }
  }
  else {
    Serial.printf("[CMD] Unknown command: %s\n", typeKey);
  }
}

// --------------------------------------------------------------------------------------
// BLE SERVER CALLBACKS
// --------------------------------------------------------------------------------------
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("App Client Connected via BLE!");
    // Kirim summary langsung saat HP konek (sync jam dilakukan app)
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("App Client Disconnected. Restarting advertising...");
    delay(100);
    pServer->startAdvertising();
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    std::string rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      for (size_t i = 0; i < rxValue.length(); i++) {
        char c = rxValue[i];
        if (c == '\n') {
          if (rxBuffer.length() > 0) {
            Serial.print("BLE Received: ");
            Serial.println(rxBuffer);
            processCommandJson(rxBuffer);
            rxBuffer = "";
          }
        } else {
          rxBuffer += c;
        }
      }
      // Fallback: Jika JSON langsung tanpa newline (beberapa klien BLE)
      if (rxBuffer.startsWith("{") && rxBuffer.endsWith("}")) {
        Serial.print("BLE Received (No Newline): ");
        Serial.println(rxBuffer);
        processCommandJson(rxBuffer);
        rxBuffer = "";
      }
    }
  }
};

// --------------------------------------------------------------------------------------
// ARDUINO SETUP
// --------------------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Pestzon Spray ESP32 Firmware v2.0 ===");

  // Setup hardware
  pinMode(PUMP_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  setRelayState(false); // Pastikan pompa MATI saat boot
  digitalWrite(LED_PIN, LOW); // Pastikan lampu mati saat boot

  // Load semua data dari NVS (tetap ada walau restart)
  loadSchedulesFromNvs();
  loadCalibrationFromNvs();
  loadLogsFromNvs();
  loadWifiConfigFromNvs();

  // Setup WiFi (non-blocking check) — hanya kalau ada config
  if (wifiEnabled) {
    connectWifi();
  }

  // Setup BLE
  BLEDevice::init("ESP32_Sprayer");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic* pRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE Ready! Advertising sebagai 'ESP32_Sprayer'.");
  Serial.printf("Flow Rate: %.2f ml/s | Jadwal: %d tersimpan\n", flowRateMlPerSec, scheduleCount);

  // Konek MQTT jika WiFi sudah online
  if (WiFi.status() == WL_CONNECTED && wifiEnabled) {
    connectMqtt();
  }
}

// --------------------------------------------------------------------------------------
// ARDUINO MAIN LOOP
// --------------------------------------------------------------------------------------
void loop() {
  // 1. Update jam internal & cek trigger jadwal otomatis
  updateInternalTime();
  checkSchedules();

  // 1.5 Cek lampu malam otomatis (Menyala 18:00 - 05:59) atau mode paksa (manual test)
  if (forceLedOn) {
    digitalWrite(LED_PIN, HIGH);
  } else if (isTimeSynced) {
    if (currentHour >= 18 || currentHour < 6) {
      digitalWrite(LED_PIN, HIGH);
    } else {
      digitalWrite(LED_PIN, LOW);
    }
  } else {
    digitalWrite(LED_PIN, LOW); // Default mati jika tidak force dan belum sync
  }

  // 2. Auto-stop pompa jika durasi tercapai
  if (isPumpRunning) {
    if (millis() - sprayStartTime >= sprayTargetDurationMs) {
      stopSpray();
    }
  }

  // 3. Maintain WiFi & MQTT (non-blocking reconnect)
  maintainWifi();
  maintainMqtt();

  delay(20);
}
