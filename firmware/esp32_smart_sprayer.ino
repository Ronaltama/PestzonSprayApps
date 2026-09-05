/*
 * ======================================================================================
 * ESP32 Smart Sprayer Firmware (BLE + Real-Time Scheduler + Relay Control)
 * Designed for FetCoreApp Flutter Application
 * ======================================================================================
 * 
 * KRITERIA PIN:
 * - Relay / Modul Pompa: GPIO 23
 * 
 * SPESIFIKASI BLE:
 * - Service UUID:        4fa1c691-e9a5-4307-9a45-500f7a6a0a9c
 * - RX Characteristic:  6e400002-b5a3-f393-e0a9-e50e24dcca9e (Write/Write Without Response)
 * - TX Characteristic:  6e400003-b5a3-f393-e0a9-e50e24dcca9e (Notify)
 *
 * DEPENDENCIES ARDUINO IDE:
 * 1. ESP32 Board Package (by Espressif Systems)
 * 2. ArduinoJson Library (v6 atau v7) - Install via Library Manager
 * ======================================================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// --------------------------------------------------------------------------------------
// HARDWARE CONFIGURATION
// --------------------------------------------------------------------------------------
#define PUMP_PIN          23      // Pin Relay Pompa
#define RELAY_ACTIVE_LOW  false   // Ubah ke true jika relay Anda Active-LOW

// Nominal Debit Pompa (ml/detik) untuk perhitungan perkiraan volume
#define FLOW_RATE_ML_PER_SEC  15.0 

// UUID BLE Kontrak FetCoreApp
#define SERVICE_UUID           "4fa1c691-e9a5-4307-9a45-500f7a6a0a9c"
#define CHARACTERISTIC_UUID_RX "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_UUID_TX "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// --------------------------------------------------------------------------------------
// DATA STRUCTURES & GLOBALS
// --------------------------------------------------------------------------------------
struct Schedule {
  int id;
  int hour;
  int minute;
  int duration;
  bool active;
  bool executedToday;
};

#define MAX_SCHEDULES 10
Schedule schedules[MAX_SCHEDULES];
int scheduleCount = 0;

Preferences preferences;

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
bool deviceConnected = false;

// Status Operasional Pompa
bool isPumpRunning = false;
unsigned long sprayStartTime = 0;
unsigned long sprayTargetDurationMs = 0;
String currentSprayMode = "Manual"; // "Manual" atau "Otomatis"

// Real-Time Clock Internal (Disinkronkan otomatis dari HP saat konek)
unsigned long lastTimeSyncMillis = 0;
int currentYear = 2026;
int currentMonth = 9;
int currentDay = 6;
int currentHour = 0;
int currentMinute = 0;
int currentSecond = 0;
bool isTimeSynced = false;

// Statistik Harian
int totalSesiToday = 0;
float totalVolumeTodayMl = 0.0;

// Buffer pesan BLE incoming
String rxBuffer = "";

// Forward Declarations
void sendSummary();
void sendSchedules();
void sendStats();
void sendAck(const char* cmd, const char* status);
void startSpray(int durationSeconds, const char* mode);
void stopSpray();

// --------------------------------------------------------------------------------------
// HELPER FUNCTIONS FOR RELAY
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
  if (year >= 2020) currentYear = year;
  if (month >= 1 && month <= 12) currentMonth = month;
  if (day >= 1 && day <= 31) currentDay = day;
  currentHour = hour;
  currentMinute = minute;
  currentSecond = second;
  lastTimeSyncMillis = millis();
  isTimeSynced = true;
  Serial.printf("ESP32 Jam Disinkronkan: %04d-%02d-%02d %02d:%02d:%02d WIB\n",
                currentYear, currentMonth, currentDay, hour, minute, second);
}

void updateInternalTime() {
  if (!isTimeSynced) return;

  unsigned long now = millis();
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

        // Reset flag eksekusi harian saat tengah malam (00:00)
        if (currentHour == 0) {
          currentDay++; // Perkiraan sederhana penambahan hari
          for (int i = 0; i < scheduleCount; i++) {
            schedules[i].executedToday = false;
          }
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
        Serial.printf("[JADWAL TRIGERRED!] Jam %02d:%02d - Durasi %ds (PIN 23 ON)\n",
                      schedules[i].hour, schedules[i].minute, schedules[i].duration);
        startSpray(schedules[i].duration, "Otomatis");
        break;
      }
    }
  }
}

// --------------------------------------------------------------------------------------
// BLE NOTIFY TRANSMITTER (20-BYTE CHUNKING UNTUK MEMENUHI ATT MTU BLE)
// --------------------------------------------------------------------------------------
void sendBleJson(const JsonDocument& doc) {
  if (!deviceConnected || pTxCharacteristic == NULL) return;

  String output;
  serializeJson(doc, output);
  output += "\n"; // Newline delimiter

  size_t len = output.length();
  size_t pos = 0;
  // Chunking per 20 byte agar tidak terpotong oleh batasan MTU BLE (ATT MTU 23 byte)
  while (pos < len) {
    size_t chunkSize = (len - pos > 20) ? 20 : (len - pos);
    pTxCharacteristic->setValue((uint8_t*)(output.c_str() + pos), chunkSize);
    pTxCharacteristic->notify();
    pos += chunkSize;
    delay(15); // Jeda kecil 15ms antar paket agar buffer BLE stack ESP32 dan HP/Linux tidak drop
  }
  Serial.print("BLE Sent: ");
  Serial.print(output);
}

// --------------------------------------------------------------------------------------
// LOG STORAGE & HISTORY (PERSISTENSI RIWAYAT SPRAY DI FLASH NVS)
// --------------------------------------------------------------------------------------
struct LogEntry {
  int durationSec;
  float volumeMl;
  char mode[16];
  char timestamp[25];
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
    logHistory[i].volumeMl = preferences.getFloat((prefix + "v").c_str(), 0.0);
    String m = preferences.getString((prefix + "m").c_str(), "Manual");
    strncpy(logHistory[i].mode, m.c_str(), sizeof(logHistory[i].mode) - 1);
    String t = preferences.getString((prefix + "t").c_str(), "");
    strncpy(logHistory[i].timestamp, t.c_str(), sizeof(logHistory[i].timestamp) - 1);
  }
  preferences.end();
}

void addLogEntry(int durationSec, float volumeMl, const char* mode) {
  if (logHistoryCount >= MAX_LOGS) {
    // Geser log terlama jika buffer penuh
    for (int i = 0; i < MAX_LOGS - 1; i++) {
      logHistory[i] = logHistory[i + 1];
    }
    logHistoryCount = MAX_LOGS - 1;
  }
  logHistory[logHistoryCount].durationSec = durationSec;
  logHistory[logHistoryCount].volumeMl = volumeMl;
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
  doc["volumeMl"] = volumeMl;
  doc["batteryPercentage"] = 0;
  doc["isSolarCharging"] = 0;
  doc["mode"] = mode;
  doc["status"] = "Sukses";
  doc["communicationMethod"] = "BLE";
  sendBleJson(doc);
}

void sendLogHistory() {
  for (int i = 0; i < logHistoryCount; i++) {
    sendLog(logHistory[i].durationSec, logHistory[i].volumeMl, logHistory[i].mode, logHistory[i].timestamp);
    delay(30);
  }
}

// --------------------------------------------------------------------------------------
// PREFERENCES / STORAGE (SAVE & LOAD SCHEDULES TO NVS)
// --------------------------------------------------------------------------------------
void saveSchedulesToNvs() {
  preferences.begin("sprayer", false);
  preferences.putInt("sched_count", scheduleCount);

  for (int i = 0; i < scheduleCount; i++) {
    String prefix = "s_" + String(i) + "_";
    preferences.putInt((prefix + "id").c_str(), schedules[i].id);
    preferences.putInt((prefix + "h").c_str(), schedules[i].hour);
    preferences.putInt((prefix + "m").c_str(), schedules[i].minute);
    preferences.putInt((prefix + "d").c_str(), schedules[i].duration);
    preferences.putBool((prefix + "a").c_str(), schedules[i].active);
  }
  preferences.end();
  Serial.printf("Tersimpan %d jadwal ke Flash NVS ESP32.\n", scheduleCount);
}

void loadSchedulesFromNvs() {
  preferences.begin("sprayer", true);
  scheduleCount = preferences.getInt("sched_count", 0);
  if (scheduleCount > MAX_SCHEDULES) scheduleCount = MAX_SCHEDULES;

  for (int i = 0; i < scheduleCount; i++) {
    String prefix = "s_" + String(i) + "_";
    schedules[i].id = preferences.getInt((prefix + "id").c_str(), i + 1);
    schedules[i].hour = preferences.getInt((prefix + "h").c_str(), 7);
    schedules[i].minute = preferences.getInt((prefix + "m").c_str(), 0);
    schedules[i].duration = preferences.getInt((prefix + "d").c_str(), 10);
    schedules[i].active = preferences.getBool((prefix + "a").c_str(), true);
    schedules[i].executedToday = false;
  }
  preferences.end();
  Serial.printf("Loaded %d schedules from Flash NVS.\n", scheduleCount);
}

// --------------------------------------------------------------------------------------
// RESPONSE BUILDERS
// --------------------------------------------------------------------------------------
void sendSummary() {
  StaticJsonDocument<300> doc;
  doc["t"] = "summary";
  doc["battery"] = 0;
  doc["voltage"] = 0.0;
  doc["isSolar"] = 0;
  doc["isPumpRunning"] = isPumpRunning ? 1 : 0;
  
  if (isPumpRunning) {
    doc["durationSec"] = (millis() - sprayStartTime) / 1000;
  } else {
    doc["durationSec"] = 0;
  }
  
  doc["totalSesi"] = totalSesiToday;
  doc["totalVolume"] = totalVolumeTodayMl;
  doc["flowRate"] = FLOW_RATE_ML_PER_SEC;
  doc["dailyTarget"] = 1000.0;
  
  sendBleJson(doc);
}

void sendSchedules() {
  StaticJsonDocument<700> doc;
  doc["t"] = "schedules";
  JsonArray arr = doc.createNestedArray("schedules");

  for (int i = 0; i < scheduleCount; i++) {
    JsonObject obj = arr.createNestedObject();
    obj["id"] = schedules[i].id;
    obj["hour"] = schedules[i].hour;
    obj["minute"] = schedules[i].minute;
    obj["duration"] = schedules[i].duration;
    obj["active"] = schedules[i].active ? 1 : 0;
  }

  sendBleJson(doc);
}

void sendStats() {
  StaticJsonDocument<300> doc;
  doc["t"] = "stats";
  JsonArray days = doc.createNestedArray("days");
  
  JsonObject todayObj = days.createNestedObject();
  todayObj["date"] = "Hari Ini";
  todayObj["volumeMl"] = totalVolumeTodayMl;

  sendBleJson(doc);
}

void sendAck(const char* cmd, const char* status) {
  StaticJsonDocument<200> doc;
  doc["t"] = "ack";
  doc["ref"] = cmd;
  doc["cmd"] = cmd;
  doc["ok"] = (strcmp(status, "ok") == 0 || strcmp(status, "1") == 0) ? 1 : 0;
  doc["status"] = status;
  sendBleJson(doc);
}


// --------------------------------------------------------------------------------------
// CONTROL FUNCTIONS
// --------------------------------------------------------------------------------------
void startSpray(int durationSeconds, const char* mode) {
  if (durationSeconds <= 0) return;

  isPumpRunning = true;
  sprayStartTime = millis();
  sprayTargetDurationMs = (unsigned long)durationSeconds * 1000;
  currentSprayMode = String(mode);

  setRelayState(true); // POMPA ON (PIN 23)
  Serial.printf("Pompa ON (PIN 23) selama %d detik [Mode: %s]\n", durationSeconds, mode);
  sendSummary();
}

void stopSpray() {
  if (!isPumpRunning) {
    setRelayState(false);
    return;
  }

  setRelayState(false); // POMPA OFF (PIN 23)
  unsigned long elapsedMs = millis() - sprayStartTime;
  int elapsedSec = elapsedMs / 1000;
  float volumeMl = elapsedSec * FLOW_RATE_ML_PER_SEC;

  isPumpRunning = false;
  totalSesiToday += 1;
  totalVolumeTodayMl += volumeMl;

  Serial.printf("Pompa OFF (PIN 23). Durasi: %ds, Volume: %.1f ml\n", elapsedSec, volumeMl);

  addLogEntry(elapsedSec, volumeMl, currentSprayMode.c_str());
  sendLog(elapsedSec, volumeMl, currentSprayMode.c_str());
  sendSummary();
}

// --------------------------------------------------------------------------------------
// INCOMING COMMAND PARSER
// --------------------------------------------------------------------------------------
void processCommandJson(const String& jsonStr) {
  StaticJsonDocument<800> doc;
  DeserializationError err = deserializeJson(doc, jsonStr);
  if (err) {
    Serial.print("JSON Error: ");
    Serial.println(err.c_str());
    return;
  }

  // 1. Ekstrak Waktu Sinkronisasi (jika disertakan oleh HP)
  if (doc.containsKey("hour") && doc.containsKey("minute")) {
    int y = doc["year"] | 2026;
    int mon = doc["month"] | 9;
    int d = doc["day"] | 6;
    int h = doc["hour"] | 0;
    int m = doc["minute"] | 0;
    int s = doc["second"] | 0;
    syncTime(y, mon, d, h, m, s);
  }

  // 2. Parse kunci "t" atau "cmd" atau "action"
  const char* typeKey = "";
  if (doc.containsKey("t")) {
    typeKey = doc["t"];
  } else if (doc.containsKey("cmd")) {
    typeKey = doc["cmd"];
  } else if (doc.containsKey("action")) {
    typeKey = doc["action"];
  }

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
    int duration = doc["duration"] | 10;
    const char* mode = doc["mode"] | "Manual";
    startSpray(duration, mode);
  } 
  else if (strcmp(typeKey, "STOP") == 0 || strcmp(typeKey, "stop") == 0) {
    stopSpray();
  } 
  else if (strcmp(typeKey, "set_schedules") == 0 || strcmp(typeKey, "sync_schedule") == 0 || strcmp(typeKey, "sync_schedules") == 0) {
    if (doc.containsKey("schedules")) {
      JsonArray arr = doc["schedules"].as<JsonArray>();
      scheduleCount = 0;

      for (JsonObject v : arr) {
        if (scheduleCount >= MAX_SCHEDULES) break;
        schedules[scheduleCount].id = v["id"] | (scheduleCount + 1);
        schedules[scheduleCount].hour = v["hour"] | 0;
        schedules[scheduleCount].minute = v["minute"] | 0;
        schedules[scheduleCount].duration = v["duration"] | (v["durationSeconds"] | 10);
        schedules[scheduleCount].active = (v["active"] | (v["isActive"] | 1)) == 1;
        schedules[scheduleCount].executedToday = false;
        scheduleCount++;
      }

      saveSchedulesToNvs();
      sendAck("sync_schedules", "ok");
      sendSchedules();
    }
  }
}

// --------------------------------------------------------------------------------------
// BLE SERVER CALLBACKS
// --------------------------------------------------------------------------------------
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("App Client Connected via BLE!");
  };

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
      for (int i = 0; i < rxValue.length(); i++) {
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
  Serial.println("\n=== Starting ESP32 Smart Sprayer Firmware ===");

  pinMode(PUMP_PIN, OUTPUT);
  setRelayState(false); // Pastikan pompa MATI saat booting

  loadSchedulesFromNvs();
  loadLogsFromNvs();

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

  Serial.println("BLE Ready! Ready to connect with FetCoreApp.");
}

// --------------------------------------------------------------------------------------
// ARDUINO MAIN LOOP
// --------------------------------------------------------------------------------------
void loop() {
  // Update Jam & Cek Trigger Jadwal Otomatis
  updateInternalTime();
  checkSchedules();

  // Handling Timer Penyemprotan (Auto Stop jika durasi tercapai)
  if (isPumpRunning) {
    if (millis() - sprayStartTime >= sprayTargetDurationMs) {
      stopSpray();
    }
  }

  delay(20);
}
