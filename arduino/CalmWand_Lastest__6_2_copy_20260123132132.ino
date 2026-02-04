/*
 * ============================================================================
 * CalmWand PCB - Biofeedback Breathing Device Firmware
 * ============================================================================
 * 
 * This firmware controls a handheld biofeedback device that:
 * - Reads skin temperature via MLX90614 infrared sensor
 * - Displays temperature feedback on a 7-LED NeoPixel ring (color gradient)
 * - Provides haptic feedback via vibration motor when temperature increases
 * - Guides breathing with a visual breath pacer (LED 0 brightness cycle)
 * - Logs session data to SD card for later analysis
 * - Communicates with a companion mobile app via Bluetooth Low Energy (BLE)
 * 
 * Hardware:
 * - Arduino Nano 33 BLE (or compatible)
 * - Adafruit NeoPixel ring (7 LEDs)
 * - MLX90614 infrared temperature sensor (I2C)
 * - Vibration motor (PWM controlled)
 * - SD card module (SPI)
 * - Breath indicator LED/circuit on BREATH_PIN
 * 
 * BLE Services:
 * - Temperature readings (notify)
 * - Settings control (brightness, breath times, motor strength)
 * - File management (list, download, delete session files)
 * - Session control (start new session)
 * 
 * Author: CalmWand Team
 * Version: 6.2
 * ============================================================================
 */

#include <Adafruit_NeoPixel.h>    // NeoPixel LED control library
#include <Adafruit_MLX90614.h>    // Infrared temperature sensor library
#include <ArduinoBLE.h>           // Bluetooth Low Energy library
#include <SD.h>                   // SD card file system library

// ============================================================================
// HARDWARE PIN CONFIGURATION
// ============================================================================
#define PIN A1              // NeoPixel data pin
#define motor_pin A3        // Vibration motor PWM pin
#define BREATH_PIN A0       // Breath indicator output pin
#define NUMPIXELS 7         // Number of LEDs in the NeoPixel ring

// ============================================================================
// TEMPERATURE RANGE CONFIGURATION
// ============================================================================
// Temperature values are stored as integers (Fahrenheit * 100)
// Example: 7000 = 70.00°F, 9800 = 98.00°F
#define Lower_Limit 7000    // Minimum temperature for color scale (70°F)
#define Upper_Limit 9800    // Maximum temperature for color scale (98°F)

// ============================================================================
// TIMING CONFIGURATION
// ============================================================================
#define MAX_LINE_LENGTH 80  // Maximum BLE packet size for file transfer
#define LOOP_INTERVAL 20    // Main loop interval in milliseconds (50Hz)

// ============================================================================
// DEVICE IDENTIFICATION
// Change this to customize your device's Bluetooth name
// ============================================================================
const char* DEVICE_NAME = "Calmwand PCB";

// ============================================================================
// BLE ADVERTISING INTERVALS
// Lower values = faster discovery but more power consumption
// Values are in units of 0.625ms
// ============================================================================
#define BLE_SLOW_ADV_INTERVAL 1600  // 1000ms interval (power saving mode)
#define BLE_FAST_ADV_INTERVAL 160   // 100ms interval (discovery mode)

// ============================================================================
// STATE MACHINE ENUMS
// These enums provide clear, readable states for different subsystems
// ============================================================================
enum SystemState { 
  STATE_IDLE,       // Device idle, waiting for connection
  STATE_ACTIVE,     // Actively connected and sending data
  STATE_LOW_POWER   // Low power mode (future use)
};

enum FileTransferState { 
  FT_IDLE,          // No transfer in progress
  FT_SENDING,       // Currently sending file data
  FT_COMPLETE,      // Transfer completed successfully
  FT_CANCELLED      // Transfer was cancelled by user
};

enum VibrationState { 
  VIB_IDLE,         // Motor off, no vibration active
  VIB_BUZZING,      // Motor on, currently vibrating
  VIB_PAUSE         // Pause between buzzes (for double-buzz pattern)
};

// ============================================================================
// HARDWARE OBJECT INSTANCES
// ============================================================================
Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);  // 7-LED ring
Adafruit_MLX90614 mlx = Adafruit_MLX90614();                      // Temp sensor

// ============================================================================
// BLE SERVICE AND CHARACTERISTICS
// ============================================================================
// Main BLE service UUID - all characteristics belong to this service
BLEService radarService("87f23fe2-4b42-11ed-bdc3-0242ac120000"); 

// Temperature characteristic - sends current averaged temperature to app
BLEStringCharacteristic temperatureCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000A", BLERead | BLENotify, 20);

// Brightness characteristic - controls maximum LED brightness (0-255)
BLEStringCharacteristic brightnessCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000B", BLERead | BLENotify | BLEWrite, 20);

// Inbreath time characteristic - duration of inhale phase in milliseconds
BLEStringCharacteristic inBreathTimeCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000C", BLERead | BLENotify | BLEWrite, 20);

// Outbreath time characteristic - duration of exhale phase in milliseconds
BLEStringCharacteristic outBreathTimeCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000D", BLERead | BLENotify | BLEWrite, 20);

// Motor strength characteristic - vibration intensity (0-255 PWM)
BLEStringCharacteristic motorStrengthCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000E", BLERead | BLENotify | BLEWrite, 20);

// File list request - write "GETLIST" to get list of session files
BLEStringCharacteristic fileListRequestChar("87f23fe2-4b42-11ed-bdc3-0242ac12000F", BLEWrite, 20);

// File name notification - sends file names during list operation
BLEStringCharacteristic fileNameChar("87f23fe2-4b42-11ed-bdc3-0242ac120010", BLERead | BLENotify, 20);

// File content request - write "GETFILE:filename" to download, "CANCEL" to stop, "DELETE:filename" to delete
BLEStringCharacteristic fileContentRequestChar("87f23fe2-4b42-11ed-bdc3-0242ac120011", BLEWrite, 32);

// File content notification - sends file data line by line, "EOF" when complete
BLEStringCharacteristic fileContentChar("87f23fe2-4b42-11ed-bdc3-0242ac120012", BLERead | BLENotify, MAX_LINE_LENGTH);

// File action - write "START" to begin new session, "DELETE:filename" to delete
BLEStringCharacteristic fileActionChar("87f23fe2-4b42-11ed-bdc3-0242ac120013", BLEWrite, 32);

// Session ID notification - sends the current session number when session starts
BLEStringCharacteristic sessionIdCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac120014", BLERead | BLENotify, 10);

// ============================================================================
// COLOR GRADIENT ARRAYS
// ============================================================================
// Temperature-to-color mapping array (14 colors from cold to hot)
// Each entry is {R, G, B} as float multipliers (0.0 to 1.0)
// Colors progress: gray -> purple -> red -> orange -> yellow -> green -> cyan -> blue -> violet -> white
const float ColorArray[14][3] = {
  { 0.25, 0.25, 0.25 },  // 0: Gray (coldest)
  { 0.3, 0, 0.3 },       // 1: Dark purple
  { 0.95, 0, 0 },        // 2: Red
  { 0.95, 0.15, 0 },     // 3: Red-orange
  { 0.95, 0.45, 0 },     // 4: Orange
  { 1, 1, 0 },           // 5: Yellow
  { 0.35, 1, 0 },        // 6: Yellow-green
  { 0, 1, 0.02 },        // 7: Green
  { 0, 1, 0.2 },         // 8: Green-cyan
  { 0, 1, 1 },           // 9: Cyan
  { 0, 0.125, 1 },       // 10: Blue
  { 0.15, 0, 1 },        // 11: Blue-violet
  { 0.6, 0, 1 },         // 12: Violet
  { 1, 1, 1 }            // 13: White (hottest)
};

// Setup animation colors (used during initialization - currently unused)
float ColorArraySetup[6][3] = {
  { 0.8, 0, 0 },         // Red
  { 0.4, 0, 0.8 },       // Purple
  { 0, 0, 1 },           // Blue
  { 0, 0.5, 0.7 },       // Cyan-blue
  { 0, 1, 0 },           // Green
  { 0, 0, 0 }            // Off
}; 

// ============================================================================
// COLOR CALCULATION VARIABLES
// ============================================================================
const int NumberOfColors = sizeof(ColorArray) / sizeof(ColorArray[0]);  // 14 colors
float OneColorRange = (Upper_Limit - Lower_Limit) / (NumberOfColors - 1);  // Temp range per color
int color1, color2;              // Packed RGB values for current colors
int color1_index, color2_index;  // Indices into ColorArray

// ============================================================================
// TEMPERATURE AVERAGING (Running Average Filter)
// ============================================================================
// Uses a circular buffer to smooth temperature readings and reduce noise
const int NumOfPoints = 50;           // Number of samples in average (1 second at 50Hz)
int tempBuffer[NumOfPoints] = {0};    // Circular buffer for temperature samples
int tempBufferIndex = 0;              // Current position in circular buffer
long tempRunningSum = 0;              // Running sum for efficient average calculation

// ============================================================================
// USER-ADJUSTABLE SETTINGS
// ============================================================================
float MotorStrength = 150;    // Vibration motor PWM intensity (0-255)
float Brightness = 0;         // Current LED brightness (varies with breath cycle)
float MaxBrightness = 125;    // Maximum LED brightness (0-255), saved to SD card

// ============================================================================
// BREATH PACER VARIABLES
// ============================================================================
// Controls the breathing guide that pulses LED 0 brightness
float BreathPacer;            // Current position in breath cycle (milliseconds)
float BreathTimer = 0;        // Timestamp when current breath cycle started
float InbreathTime = 4500;    // Inhale duration in milliseconds (4.5 seconds default)
float OutbreathTime = 9000;   // Exhale duration in milliseconds (9 seconds default)
float BreathCycleTime = InbreathTime + OutbreathTime;  // Total cycle time

// ============================================================================
// VIBRATION MOTOR CONTROL
// ============================================================================
// Haptic feedback system - buzzes when temperature increases (LED count increases)
bool vibration = 0;                    // Legacy flag (kept for compatibility)
unsigned long vibration_start = 0;     // Timestamp when vibration started
unsigned long lastVibrationEndTime = 0;  // When last vibration ended (5-sec cooldown)
int vibrationBuzzCount = 0;            // Buzzes remaining (1=single, 2=double)
int vibrationBuzzPhase = 0;            // Legacy: 0=buzzing, 1=pause (replaced by enum)
unsigned long vibrationPhaseStart = 0; // Timestamp for current vibration phase
int no_vibration_count = 0;            // Counter to reset vibration progress tracking
int NumberOfLedsOn = 0;                // Current number of LEDs showing "hot" color
int previous_num_led_on = 0;           // Previous LED count (for change detection)
bool vibration_progress[NumberOfColors * 6];  // Tracks which LED positions have vibrated

// ============================================================================
// BLE CONNECTION STATE
// ============================================================================
bool cancelRequested = false;  // Flag to cancel file transfer
bool wasConnected = false;     // Tracks if BLE central is connected

// ============================================================================
// STATE MACHINE VARIABLES
// ============================================================================
SystemState systemState = STATE_IDLE;      // Overall system state
FileTransferState ftState = FT_IDLE;       // File transfer state machine
VibrationState vibState = VIB_IDLE;        // Vibration state machine

// ============================================================================
// BLE POWER MANAGEMENT
// ============================================================================
unsigned long lastBleActivityTime = 0;  // Last time BLE was active (for power saving)
bool bleAdvertising = true;             // Whether BLE is currently advertising
bool slowAdvertising = false;           // Whether using slow (power-saving) advertising

// ============================================================================
// FILE TRANSFER STATE
// ============================================================================
File ftFile;                   // File handle for ongoing transfer
unsigned long ftByteCount = 0; // Bytes transferred so far

// ============================================================================
// SD CARD AND SESSION LOGGING
// ============================================================================
const int chipSelect = D7;     // SD card SPI chip select pin
File myFile;                   // Current session log file
int fileNumber = 0;            // Current session number
unsigned long previousMillis = 0;  // Last SD write timestamp
const long interval = 1000;    // SD logging interval (1 second)
char fileNameBuffer[20];       // Buffer for constructing filenames

// ============================================================================
// TIMING VARIABLES
// ============================================================================
unsigned long lastLoopTime = 0;      // Last main loop execution time
unsigned long lastTempSendTime = 0;  // Last debug print timestamp

// ============================================================================
// FUNCTION IMPLEMENTATIONS
// ============================================================================

/**
 * Non-blocking BLE notify helper
 * Sets characteristic value without blocking - main loop handles BLE.poll()
 * 
 * @param ch      Reference to BLE characteristic to update
 * @param payload String value to send
 * @return        Always returns true (for API consistency)
 */
bool safeNotify(BLECharacteristic &ch, const char *payload) {
  ch.setValue(payload);
  return true;
}

/**
 * Switch BLE advertising between fast and slow modes
 * Fast mode (100ms interval) for quick discovery when user is connecting
 * Slow mode (1000ms interval) to save battery when idle
 * 
 * @param fast  true for fast advertising, false for slow/power-saving
 */
void setBleAdvertisingMode(bool fast) {
  if (fast && slowAdvertising) {
    // Switch to fast mode
    BLE.stopAdvertise();
    BLE.setAdvertisingInterval(BLE_FAST_ADV_INTERVAL);
    BLE.advertise();
    slowAdvertising = false;
    Serial.println("BLE: Fast advertising mode");
  } else if (!fast && !slowAdvertising) {
    // Switch to slow/power-saving mode
    BLE.stopAdvertise();
    BLE.setAdvertisingInterval(BLE_SLOW_ADV_INTERVAL);
    BLE.advertise();
    slowAdvertising = true;
    Serial.println("BLE: Slow advertising mode (power save)");
  }
}

/**
 * Stop BLE advertising entirely (maximum power savings)
 * Device will not be discoverable until advertising is resumed
 */
void stopBleAdvertising() {
  if (bleAdvertising) {
    BLE.stopAdvertise();
    bleAdvertising = false;
    Serial.println("BLE: Advertising stopped (idle timeout)");
  }
}

/**
 * Resume BLE advertising in fast mode
 * Called when device needs to become discoverable again
 */
void startBleAdvertising() {
  if (!bleAdvertising) {
    BLE.setAdvertisingInterval(BLE_FAST_ADV_INTERVAL);
    BLE.advertise();
    bleAdvertising = true;
    slowAdvertising = false;
    lastBleActivityTime = millis();
    Serial.println("BLE: Advertising resumed");
  }
}

/**
 * Efficient running average filter for temperature smoothing
 * Uses a circular buffer and running sum to avoid recalculating entire average
 * 
 * Algorithm:
 * 1. Subtract oldest value from running sum
 * 2. Add new value to buffer and running sum
 * 3. Advance buffer index (wraps around)
 * 4. Return running sum / number of samples
 * 
 * @param newTemp  New temperature reading (Fahrenheit * 100)
 * @return         Smoothed average temperature
 */
int GetOptimizedAverage(int newTemp) {
  // Validate input - reject obviously invalid readings
  if (newTemp <= 0 || newTemp > 20000) {
     // Return current average if we have valid data, otherwise return raw value
     if (tempRunningSum > 0) return tempRunningSum / NumOfPoints;
     return newTemp;
  }
  
  // Subtract oldest sample from running sum
  tempRunningSum -= tempBuffer[tempBufferIndex];
  
  // Store new sample in buffer
  tempBuffer[tempBufferIndex] = newTemp;
  
  // Add new sample to running sum
  tempRunningSum += newTemp;
  
  // Advance circular buffer index
  tempBufferIndex++;
  if (tempBufferIndex >= NumOfPoints) tempBufferIndex = 0;
  
  // Return average
  return tempRunningSum / NumOfPoints;
}

/**
 * Get the next available session ID for data logging
 * 
 * First checks cache file (nextsid.txt) for performance.
 * If cache doesn't exist, scans all data files to find highest number.
 * Session files are named "dataX.txt" where X is the session number.
 * 
 * @return  Next available session ID (0 if first session)
 */
int getNextSessionId() {
  // Try to read cached next session ID first (faster)
  if (SD.exists("nextsid.txt")) {
    File cache = SD.open("nextsid.txt", FILE_READ);
    if (cache) {
      String line = cache.readStringUntil('\n');
      cache.close();
      line.trim();
      int cached = line.toInt();
      if (cached >= 0) {
        return cached;
      }
    }
  }

  // Cache miss - scan directory for highest session number
  int maxNum = -1;
  File root = SD.open("/");
  if (root) {
    File entry = root.openNextFile();
    while (entry) {
      String name = entry.name();
      String lname = name;
      lname.toLowerCase();

      // Look for files matching pattern "dataX.txt"
      if (lname.startsWith("data") && lname.endsWith(".txt")) {
        // Extract number from filename
        String numStr = lname.substring(4, lname.length() - 4);
        int n = numStr.toInt();
        maxNum = max(maxNum, n);
      }
      entry.close();
      entry = root.openNextFile();
    }
    root.close();
  }
  
  // Return next number after highest found
  return maxNum + 1;
}

/**
 * Save the next session ID to cache file for faster startup
 * 
 * @param nextId  The session ID to cache
 */
void saveNextSessionIdCache(int nextId) {
  // Remove old cache file if exists
  if (SD.exists("nextsid.txt")) {
    SD.remove("nextsid.txt");
  }
  
  // Write new cache value
  File cache = SD.open("nextsid.txt", FILE_WRITE);
  if (cache) {
    cache.println(nextId);
    cache.close();
  }
}

/**
 * Start a new data logging session
 * 
 * Closes any existing session file, determines next session ID,
 * creates new data file, and notifies connected BLE central of new session.
 * Called at startup and when app requests new session via BLE.
 */
void startNewSession() {
  Serial.println("BLE DEBUG: startNewSession() called");
  
  // Close previous session file if open
  if (myFile) {
    myFile.close();
    Serial.println("BLE DEBUG: Closed previous file");
  }

  // Get next session number
  fileNumber = getNextSessionId();
  Serial.print("BLE DEBUG: Got SessionID: ");
  Serial.println(fileNumber);
  
  // Create filename: "data0.txt", "data1.txt", etc.
  snprintf(fileNameBuffer, sizeof(fileNameBuffer), "data%d.txt", fileNumber);
  Serial.print("BLE DEBUG: Opening file: ");
  Serial.println(fileNameBuffer);

  // Open new session file for writing
  myFile = SD.open(fileNameBuffer, FILE_WRITE);
  if (myFile) {
    // Update cache for next session
    saveNextSessionIdCache(fileNumber + 1);
    Serial.println("BLE DEBUG: File opened successfully");
  } else {
    Serial.println("BLE DEBUG: ERROR - Failed to open file!");
  }
  
  // Notify connected BLE central of new session ID
  String sidStr = String(fileNumber);
  Serial.print("BLE DEBUG: Sending SessionID notification: '");
  Serial.print(sidStr);
  Serial.println("'");
  
  sessionIdCharacteristic.setValue(sidStr);
  
  // Brief poll to ensure notification is sent
  unsigned long start = millis();
  while (millis() - start < 50) { BLE.poll(); }
  
  Serial.println("BLE DEBUG: SessionID notification sent");
}

// ============================================================================
// ARDUINO SETUP - Runs once at startup
// ============================================================================
void setup() {
  // Initialize serial for debugging (115200 baud)
  Serial.begin(115200);
  // Wait for serial connection (with 2 second timeout for non-USB scenarios)
  while (!Serial && millis() < 2000); 

  // Configure output pins
  pinMode(motor_pin, OUTPUT);        // Vibration motor
  pinMode(BREATH_PIN, OUTPUT);       // Breath indicator
  digitalWrite(BREATH_PIN, LOW);     // Start with breath indicator off

  // Initialize temperature sensor (I2C)
  mlx.begin();
  
  // Initialize NeoPixel LEDs
  pixels.begin();
  pixels.clear();
  pixels.show();

  // Initialize temperature averaging buffer to zeros
  for(int i=0; i<NumOfPoints; i++) tempBuffer[i] = 0;

  // Initialize SD card
  if (SD.begin(chipSelect)) {
    // Start first data logging session
    startNewSession(); 
    
    // Load saved brightness setting from config file
    if (SD.exists("config.txt")) {
      File cfg = SD.open("config.txt", FILE_READ);
      if (cfg) {
        String line = cfg.readStringUntil('\n');
        line.trim();
        int stored = line.toInt();
        if (stored >= 0 && stored <= 255) {
          MaxBrightness = stored;
        }
        cfg.close();
      }
    }
  } else {
    Serial.println("BLE DEBUG: SD Card Init Failed - File operations will fail.");
  }

  // Initialize BLE
  if (!BLE.begin()) {
    Serial.println("BLE DEBUG: BLE Hardware Init Failed!");
    while(1);  // Halt if BLE fails
  }
  
  // Configure BLE device name (visible to mobile app)
  BLE.setDeviceName(DEVICE_NAME);
  BLE.setLocalName(DEVICE_NAME);
  Serial.print("BLE: Device name set to: ");
  Serial.println(DEVICE_NAME);
  
  // Set up BLE service
  BLE.setAdvertisedService(radarService);

  // Add all characteristics to the service
  radarService.addCharacteristic(temperatureCharacteristic);   // Temperature data
  radarService.addCharacteristic(brightnessCharacteristic);    // LED brightness control
  radarService.addCharacteristic(inBreathTimeCharacteristic);  // Inhale duration
  radarService.addCharacteristic(outBreathTimeCharacteristic); // Exhale duration
  radarService.addCharacteristic(motorStrengthCharacteristic); // Vibration intensity
  radarService.addCharacteristic(fileListRequestChar);         // Request file list
  radarService.addCharacteristic(fileNameChar);                // File name notifications
  radarService.addCharacteristic(fileContentRequestChar);      // Request file content
  radarService.addCharacteristic(fileContentChar);             // File content notifications
  radarService.addCharacteristic(fileActionChar);              // Session/file actions
  radarService.addCharacteristic(sessionIdCharacteristic);     // Session ID notifications

  // Register service and start advertising
  BLE.addService(radarService);
  BLE.advertise();
  
  // Set initial values for readable characteristics
  brightnessCharacteristic.setValue(String(MaxBrightness));
  inBreathTimeCharacteristic.setValue(String(InbreathTime));
  outBreathTimeCharacteristic.setValue(String(OutbreathTime));
  motorStrengthCharacteristic.setValue(String(MotorStrength));

  // Initialize vibration progress tracking array
  for (int i = 0; i < NumberOfColors * 6; i++) {
    vibration_progress[i] = 0;
  } 
  
  // Start breath cycle timer
  BreathTimer = millis();
  
  Serial.println("BLE DEBUG: System Ready. Advertising started.");
}

// ============================================================================
// COLOR UTILITY FUNCTIONS
// ============================================================================

/**
 * Convert RGB float values to packed NeoPixel color integer
 * Applies brightness multiplier to each channel
 * 
 * @param RGBValues    Array of {R, G, B} floats (0.0 to 1.0 scale)
 * @param brightnessVal  Brightness multiplier (0 to 255)
 * @return             Packed 24-bit RGB color for NeoPixel
 */
int ConvertRGBtoInt(float RGBValues[3], float brightnessVal) {
  int R = round(brightnessVal * (RGBValues[0]));
  int G = round(brightnessVal * (RGBValues[1]));
  int B = round(brightnessVal * (RGBValues[2]));
  return pixels.Color(R, G, B);
};

/**
 * Determine which two colors to blend based on temperature
 * Maps temperature to position in color gradient array
 * 
 * @param Temp    Current temperature (Fahrenheit * 100)
 * @param Colors  Output array: [0]=lower color index, [1]=upper color index
 */
void DetermineColors(float Temp, int Colors[2]) {
  for (int i = 0; i < NumberOfColors; i++) {
    if (Temp < Lower_Limit) {
      // Below minimum - use coldest color
      color1_index = 0; color2_index = 0; break;
    } else if (Temp < Lower_Limit + (i + 1) * OneColorRange) {
      // In range - use this color pair
      color1_index = i; color2_index = i + 1; break;
    } else if (Temp > Upper_Limit) {
      // Above maximum - use hottest color
      color1_index = NumberOfColors - 1; color2_index = NumberOfColors - 1; break;
    }
  }
  Colors[0] = color1_index;
  Colors[1] = color2_index;
}

/**
 * Calculate how many LEDs should show the "hotter" color
 * Temperature progress within a color range maps to LED count (0-6)
 * Includes hysteresis to prevent flickering at boundaries
 * 
 * @param Temp          Current temperature (Fahrenheit * 100)
 * @param currentLedsOn Previous LED count (for hysteresis)
 * @return              Number of LEDs to show in "hot" color (0-7)
 */
int DetermineNumberofLedsOn(float Temp, int currentLedsOn) {
  // Calculate position within current color range
  float baseline = Temp - Lower_Limit;
  float remainder = fmod(baseline, OneColorRange);
  float OneLedRange = OneColorRange / 6;  // Each LED represents 1/6 of color range
  float threshold = 0.5 * OneLedRange;    // Hysteresis threshold

  // Calculate raw LED count
  int numLeds = static_cast<int>(remainder / OneLedRange);

  // Apply hysteresis - resist decreasing LED count unless clearly below threshold
  if (numLeds < currentLedsOn) {
    if (remainder > (numLeds + 1) * OneLedRange - threshold) {
      numLeds = currentLedsOn;  // Stay at current count
    }
  }
  
  // Clamp to valid range
  return min(7, max(numLeds, 0));
}

// ============================================================================
// FILE TRANSFER FUNCTIONS (Non-blocking state machine)
// ============================================================================

/**
 * Initialize a file transfer operation
 * Opens the requested file and sets up transfer state machine
 * Call processFileTransfer() each loop iteration to send data
 * 
 * @param filename  Name of file to transfer from SD card
 */
void startFileTransfer(const String &filename) {
  Serial.print("BLE DEBUG: >> Starting file transfer: "); Serial.println(filename);
  
  // Close any previous transfer in progress
  if (ftFile) ftFile.close();
  
  // Open requested file
  ftFile = SD.open(filename, FILE_READ);
  if (!ftFile) {
    Serial.println("BLE DEBUG: >> Error: File not found on SD.");
    ftState = FT_IDLE;
    fileContentChar.setValue("ERROR:NOTFOUND");
    return;
  }

  // Initialize transfer state
  cancelRequested = false;
  ftByteCount = 0;
  ftState = FT_SENDING;
  lastBleActivityTime = millis();  // Keep BLE active during transfer
}

/**
 * Process one chunk of file transfer (non-blocking)
 * Sends one line per call - must be called repeatedly from main loop
 * Sends "EOF" when transfer completes
 */
void processFileTransfer() {
  if (ftState != FT_SENDING) return;
  
  // Check if cancel was requested
  if (cancelRequested) {
    Serial.println("BLE DEBUG: >> Transfer Cancelled by Central.");
    ftFile.close();
    ftState = FT_CANCELLED;
    return;
  }
  
  // Send one line per loop iteration
  if (ftFile.available()) {
    String line = ftFile.readStringUntil('\n');
    ftByteCount += line.length();
    
    if (line.length() > 0) {
      fileContentChar.setValue(line);
    }
    lastBleActivityTime = millis();
  } else {
    // Transfer complete
    ftFile.close();
    Serial.print("BLE DEBUG: >> Transfer Complete. Bytes sent: "); Serial.println(ftByteCount);
    fileContentChar.setValue("EOF");
    ftState = FT_COMPLETE;
  }
}

/**
 * Blocking file transfer (legacy compatibility wrapper)
 * Wraps non-blocking functions for simple usage
 * 
 * @param filename  Name of file to transfer
 */
void sendFileContent(const String &filename) {
  startFileTransfer(filename);
  while (ftState == FT_SENDING) {
    BLE.poll();
    processFileTransfer();
    delay(5);  // Small delay between chunks for BLE stability
  }
}

// ============================================================================
// BLE COMMAND HANDLER
// ============================================================================
/**
 * Process all BLE characteristic write events
 * Called from main loop when a central device is connected
 * 
 * Handles:
 * - Settings updates (brightness, breath times, motor strength)
 * - File list requests (GETLIST command)
 * - File content requests (GETFILE, CANCEL, DELETE commands)
 * - Session actions (START, DELETE commands)
 */
void handleBleCommands() {
  
  // -------------------------------------------------------------------------
  // BRIGHTNESS SETTING - Controls maximum LED brightness (0-255)
  // -------------------------------------------------------------------------
  if (brightnessCharacteristic.written()) {
    float val = brightnessCharacteristic.value().toFloat();
    Serial.print("BLE DEBUG: Write Brightness: "); Serial.println(val);
    MaxBrightness = constrain(val, 0, 255);
    
    // Persist to SD card for next boot
    SD.remove("config.txt");
    File cfg = SD.open("config.txt", FILE_WRITE);
    if (cfg) { cfg.println((int)MaxBrightness); cfg.close(); }
    
    // Echo back confirmed value
    brightnessCharacteristic.setValue(String(MaxBrightness));
  }
  
  // -------------------------------------------------------------------------
  // INBREATH TIME - Duration of inhale phase (milliseconds)
  // -------------------------------------------------------------------------
  if (inBreathTimeCharacteristic.written()) {
    InbreathTime = inBreathTimeCharacteristic.value().toFloat(); 
    BreathCycleTime = InbreathTime + OutbreathTime;  // Recalculate total cycle
    Serial.print("BLE DEBUG: Write InBreath: "); Serial.println(InbreathTime);
    inBreathTimeCharacteristic.setValue(String(InbreathTime));
  }

  // -------------------------------------------------------------------------
  // OUTBREATH TIME - Duration of exhale phase (milliseconds)
  // -------------------------------------------------------------------------
  if (outBreathTimeCharacteristic.written()) {
    OutbreathTime = outBreathTimeCharacteristic.value().toFloat();
    BreathCycleTime = InbreathTime + OutbreathTime;  // Recalculate total cycle
    Serial.print("BLE DEBUG: Write OutBreath: "); Serial.println(OutbreathTime);
    outBreathTimeCharacteristic.setValue(String(OutbreathTime));
  }

  // -------------------------------------------------------------------------
  // MOTOR STRENGTH - Vibration intensity (0-255 PWM)
  // -------------------------------------------------------------------------
  if (motorStrengthCharacteristic.written()) {
    MotorStrength = constrain(motorStrengthCharacteristic.value().toFloat(), 0, 255);
    Serial.print("BLE DEBUG: Write Motor: "); Serial.println(MotorStrength);
    motorStrengthCharacteristic.setValue(String(MotorStrength));
  }
  
  // -------------------------------------------------------------------------
  // FILE LIST REQUEST - Returns list of all session files on SD card
  // Format: "sessionId:filename:estimatedMinutes"
  // -------------------------------------------------------------------------
  if (fileListRequestChar.written()) {
    if (fileListRequestChar.value() == "GETLIST") {
       Serial.println("BLE DEBUG: Command GETLIST received.");
       File root = SD.open("/");
       if (root) {
         File entry = root.openNextFile();
         while (entry) {
           if (!entry.isDirectory()) {
             String fname = String(entry.name());
             
             // Extract session ID from filename (e.g., "data5.txt" -> 5)
             int sid = fname.substring(4, fname.length() - 4).toInt(); 
             
             // Estimate session duration from file size
             // Each line is ~14 bytes, logged once per second
             unsigned long fsize = entry.size();
             int estimatedMins = (fsize / 14) / 60;
             if (estimatedMins < 1) estimatedMins = 1; 
             
             // Format: "sessionId:filename:minutes"
             String out = String(sid) + ":" + fname + ":" + String(estimatedMins); 
             
             fileNameChar.setValue(out);
             Serial.print("BLE DEBUG: Listing File -> "); Serial.println(out);
             
             // Brief poll to ensure notification is sent
             unsigned long start = millis();
             while (millis() - start < 15) { BLE.poll(); }
           }
           entry.close();
           entry = root.openNextFile();
         }
         root.close();
         
         // Send END marker to indicate list complete
         fileNameChar.setValue("END");
         Serial.println("BLE DEBUG: End of File List.");
         
         unsigned long start = millis();
         while (millis() - start < 20) { BLE.poll(); } 
       } else {
         Serial.println("BLE DEBUG: SD Root open failed.");
       }
    }
  }

  // -------------------------------------------------------------------------
  // FILE CONTENT REQUEST - Download, cancel, or delete files
  // Commands: "GETFILE:filename", "CANCEL", "DELETE:filename"
  // -------------------------------------------------------------------------
  if (fileContentRequestChar.written()) {
    String cmd = fileContentRequestChar.value();
    Serial.print("BLE DEBUG: Content Req: "); Serial.println(cmd);
    
    if (cmd.startsWith("GETFILE:")) {
      // Download file contents
      String filename = cmd.substring(8);
      filename.trim();
      sendFileContent(filename);
    }
    else if (cmd == "CANCEL") { 
      // Cancel ongoing transfer
      cancelRequested = true; 
      Serial.println("BLE DEBUG: Cancel Flag Set.");
    }
    else if (cmd.startsWith("DELETE:")) {
      // Delete file from SD card
      String filename = cmd.substring(7);
      filename.trim();
      if (SD.exists(filename)) {
        SD.remove(filename);
        // Invalidate session ID cache since file numbers may have gaps now
        if (SD.exists("nextsid.txt")) SD.remove("nextsid.txt");
        Serial.print("BLE DEBUG: File Deleted: "); Serial.println(filename);
      } else {
        Serial.print("BLE DEBUG: Delete failed, file missing: "); Serial.println(filename);
      }
    }
  }

  // -------------------------------------------------------------------------
  // FILE/SESSION ACTIONS - Start new session or delete files
  // Commands: "START", "DELETE:filename"
  // -------------------------------------------------------------------------
  if (fileActionChar.written()) {
    String cmd = fileActionChar.value();
    Serial.print("BLE DEBUG: Action Req: "); Serial.println(cmd);
    
    if (cmd == "START") {
      // Start a new logging session
      startNewSession();
      Serial.println("BLE DEBUG: New Session Started via BLE.");
    } else if (cmd.startsWith("DELETE:")) {
      // Delete file and notify result
      String fname = cmd.substring(7);
      fname.trim();
      if (SD.exists(fname)) {
        SD.remove(fname);
        if (SD.exists("nextsid.txt")) SD.remove("nextsid.txt");
        fileNameChar.setValue("DELETED:" + fname);
        
        unsigned long start = millis();
        while (millis() - start < 15) { BLE.poll(); }
        Serial.print("BLE DEBUG: Action Delete success: "); Serial.println(fname);
      } else {
        fileNameChar.setValue("ERROR:NOTFOUND:" + fname);
        Serial.print("BLE DEBUG: Action Delete fail (not found): "); Serial.println(fname);
      }
    }
  }

}

// ============================================================================
// MAIN LOOP - Runs continuously after setup()
// ============================================================================
/**
 * Main program loop - executes at ~50Hz (every 20ms)
 * 
 * Responsibilities:
 * 1. Poll BLE for incoming data
 * 2. Track BLE connection state
 * 3. Read and average temperature sensor
 * 4. Update breath pacer (LED brightness cycling)
 * 5. Determine LED colors based on temperature
 * 6. Handle vibration motor state machine
 * 7. Update NeoPixel LEDs
 * 8. Send temperature via BLE
 * 9. Log data to SD card
 */
void loop() {
  // Poll BLE stack for incoming data and connection events
  BLE.poll();
  
  // Get current timestamp for timing calculations
  unsigned long currentMillis = millis();

  // =========================================================================
  // BLE CONNECTION STATE TRACKING
  // =========================================================================
  BLEDevice central = BLE.central();
  if (central) {
    // A central device is connected
    if (!wasConnected) {
      // New connection - log and set up
      Serial.print("BLE DEBUG: Device Connected. Address: ");
      Serial.println(central.address());
      wasConnected = true;
      lastBleActivityTime = currentMillis;
      
      // Ensure we're advertising in fast mode for future connections
      if (!bleAdvertising) startBleAdvertising();
      setBleAdvertisingMode(true);
    }
    
    // Process any pending BLE commands from the central
    handleBleCommands();
    lastBleActivityTime = currentMillis;  // Reset idle timer
    
  } else {
    // No central connected
    if (wasConnected) {
      // Just disconnected - log and clean up
      Serial.println("BLE DEBUG: Device Disconnected.");
      wasConnected = false;
      lastBleActivityTime = currentMillis;
      
      // Cancel any file transfer in progress
      if (ftState == FT_SENDING) {
        ftFile.close();
        ftState = FT_IDLE;
      }
    }
  }

  // =========================================================================
  // MAIN LOOP BODY - Runs every LOOP_INTERVAL (20ms = 50Hz)
  // =========================================================================
  if (currentMillis - lastLoopTime >= LOOP_INTERVAL) {
    lastLoopTime = currentMillis;

    // -----------------------------------------------------------------------
    // A. TEMPERATURE READING AND AVERAGING
    // -----------------------------------------------------------------------
    // Read infrared sensor (object temperature in Fahrenheit)
    // Multiply by 100 to store as integer (e.g., 85.5°F -> 8550)
    int rawTemp = 100 * mlx.readObjectTempF();
    
    // Apply running average filter to smooth readings
    float AverageTemp = GetOptimizedAverage(rawTemp);
    
    // -----------------------------------------------------------------------
    // B. BREATH PACER - Cycles LED brightness to guide breathing
    // -----------------------------------------------------------------------
    // Calculate position in current breath cycle
    BreathPacer = currentMillis - BreathTimer;
    
    if (BreathPacer < InbreathTime) {
      // INHALE PHASE - Brightness increases with squared curve (slow start, fast end)
      Brightness = MaxBrightness * pow((BreathPacer / InbreathTime), 2);
      digitalWrite(BREATH_PIN, HIGH);  // Breath indicator ON
      pixels.setPixelColor(0, pixels.Color(0, 20, 0));  // LED 0 = green (breathing indicator)
    } 
    else if (BreathPacer < BreathCycleTime) {
      // EXHALE PHASE - Brightness decreases with squared curve
      float progress = BreathPacer - InbreathTime;
      Brightness = MaxBrightness * pow(-(progress - OutbreathTime) / OutbreathTime, 2);
      digitalWrite(BREATH_PIN, LOW);   // Breath indicator OFF
      pixels.setPixelColor(0, 0);       // LED 0 = off during exhale
    } 
    else {
      // Cycle complete - restart
      BreathTimer = currentMillis; 
    }

    // -----------------------------------------------------------------------
    // C. COLOR AND LED COUNT CALCULATION
    // -----------------------------------------------------------------------
    // Determine which two colors we're between based on temperature
    int Colors[2];
    DetermineColors(AverageTemp, Colors);
    
    // Determine how many LEDs show the "hotter" color (0-7)
    NumberOfLedsOn = DetermineNumberofLedsOn(AverageTemp, NumberOfLedsOn);

    // -----------------------------------------------------------------------
    // D. VIBRATION MOTOR LOGIC - Haptic feedback on temperature increase
    // -----------------------------------------------------------------------
    // Calculate unique index for current LED position (for progress tracking)
    // Each color has 6 LED positions, so index = colorIndex * 6 + ledCount
    int currentLedIndex = color1_index * 6 + NumberOfLedsOn;
    
    // Detect completion of full color (all 6 LEDs, wrapping to next color)
    // This happens when LEDs go from 5 to 0 (transitioning to next color)
    bool completedFullColor = (NumberOfLedsOn == 0 && previous_num_led_on == 5);
    
    // Debug: Log LED state changes
    if (NumberOfLedsOn != previous_num_led_on) {
      Serial.print("VIBRATION DEBUG: LEDs changed from ");
      Serial.print(previous_num_led_on);
      Serial.print(" to ");
      Serial.print(NumberOfLedsOn);
      Serial.print(" | color1_index=");
      Serial.print(color1_index);
      Serial.print(" | completedFullColor=");
      Serial.println(completedFullColor ? "YES" : "NO");
    }
    
    // Trigger vibration when:
    // - LED count increased OR completed full color transition
    // - This position hasn't vibrated yet (vibration_progress)
    // - At least 5 seconds since last vibration (cooldown)
    // - No vibration currently in progress
    if ((NumberOfLedsOn > previous_num_led_on || completedFullColor) 
        && vibration_progress[currentLedIndex] == 0
        && (currentMillis - lastVibrationEndTime >= 5000)
        && vibState == VIB_IDLE) {
      
      // Double buzz for completing full color, single buzz for LED increment
      if (completedFullColor) {
        vibrationBuzzCount = 2;  // Double buzz pattern
        Serial.println("VIBRATION DEBUG: *** DOUBLE BUZZ - Full color completed! ***");
      } else {
        vibrationBuzzCount = 1;  // Single buzz
        Serial.println("VIBRATION DEBUG: Single buzz - LED increment");
      }
      
      // Start vibration state machine
      vibration = 1;
      vibration_start = currentMillis;
      vibState = VIB_BUZZING;
      vibrationPhaseStart = currentMillis;
      
      // Mark all positions up to current as "vibrated"
      for (int i = 0; i <= currentLedIndex; i++) { vibration_progress[i] = 1; }
      
    } else if ((NumberOfLedsOn > previous_num_led_on || completedFullColor) && NumberOfLedsOn != previous_num_led_on) {
      // Debug: Log why vibration was blocked
      Serial.print("VIBRATION DEBUG: Blocked! ");
      if (vibration_progress[currentLedIndex] != 0) Serial.print("progress_blocked ");
      if (currentMillis - lastVibrationEndTime < 5000) {
        Serial.print("5sec_delay(");
        Serial.print(5000 - (currentMillis - lastVibrationEndTime));
        Serial.print("ms left) ");
      }
      if (vibState != VIB_IDLE) Serial.print("buzz_in_progress ");
      Serial.println();
    }

    // Reset vibration progress tracking after 10 iterations of stable temperature
    // This allows re-triggering if user warms up again after cooling down
    if (NumberOfLedsOn == previous_num_led_on && vibState == VIB_IDLE) {
      no_vibration_count++;
      if (no_vibration_count >= 10) { 
        // Reset all progress markers
        for (int i = 0; i < NumberOfColors * 6; i++) { vibration_progress[i] = 0; }
        no_vibration_count = 0; 
      }
    } else {
      no_vibration_count = 0;
    }

    // -----------------------------------------------------------------------
    // VIBRATION STATE MACHINE - Handles single and double buzz patterns
    // -----------------------------------------------------------------------
    switch (vibState) {
      case VIB_BUZZING:
        // Motor ON - buzzing phase
        analogWrite(motor_pin, MotorStrength);
        
        // Check if buzz duration complete (300ms)
        if (currentMillis - vibrationPhaseStart > 300) {
          Serial.print("VIBRATION DEBUG: Buzz #");
          Serial.print(vibrationBuzzCount);
          Serial.println(" complete");
          
          vibrationBuzzCount--;
          analogWrite(motor_pin, 0);  // Motor OFF
          
          if (vibrationBuzzCount > 0) {
            // More buzzes remaining - enter pause phase
            Serial.println("VIBRATION DEBUG: Entering pause before next buzz");
            vibState = VIB_PAUSE;
            vibrationPhaseStart = currentMillis;
          } else {
            // All buzzes complete - return to idle
            Serial.println("VIBRATION DEBUG: All buzzes complete");
            vibState = VIB_IDLE;
            vibration = 0;
            lastVibrationEndTime = currentMillis;  // Start 5-second cooldown
          }
        }
        break;
        
      case VIB_PAUSE:
        // Motor OFF - pause between buzzes (200ms)
        analogWrite(motor_pin, 0);
        
        if (currentMillis - vibrationPhaseStart > 200) {
          // Pause complete - start next buzz
          Serial.println("VIBRATION DEBUG: Starting next buzz");
          vibState = VIB_BUZZING;
          vibrationPhaseStart = currentMillis;
        }
        break;
        
      case VIB_IDLE:
      default:
        // Motor OFF - no vibration active
        analogWrite(motor_pin, 0);
        break;
    }
    
    // Save LED count for next iteration's change detection
    previous_num_led_on = NumberOfLedsOn;

    // -----------------------------------------------------------------------
    // E. UPDATE NEOPIXEL LEDS
    // -----------------------------------------------------------------------
    // Convert color arrays to packed RGB values with current brightness
    color1 = ConvertRGBtoInt((float*)ColorArray[Colors[0]], Brightness);
    color2 = ConvertRGBtoInt((float*)ColorArray[Colors[1]], Brightness);

    // Set LED colors:
    // - LED 0: Breath indicator (handled in breath logic above)
    // - LEDs 1 to NumberOfLedsOn: "Hot" color (color2)
    // - LEDs NumberOfLedsOn+1 to 6: "Cold" color (color1)
    for (int i = 1; i <= NumberOfLedsOn; i++) { pixels.setPixelColor(i, color2); }
    for (int i = NumberOfLedsOn + 1; i < 7; i++) { pixels.setPixelColor(i, color1); }
    
    // Push colors to LEDs
    pixels.show();

    // -----------------------------------------------------------------------
    // F. SEND TEMPERATURE VIA BLE
    // -----------------------------------------------------------------------
    if (wasConnected) {
       // Send current averaged temperature to connected central
       String tempStr = String(AverageTemp);
       temperatureCharacteristic.setValue(tempStr);
       
       // Debug output (throttled to every 500ms to avoid serial flood)
       if (currentMillis - lastTempSendTime >= 500) {
         lastTempSendTime = currentMillis;
         Serial.print("BLE TX: Temp=");
         Serial.print(tempStr);
         Serial.print(" | Raw=");
         Serial.print(rawTemp);
         Serial.print(" | Connected=");
         Serial.println(wasConnected ? "YES" : "NO");
       }
       
       // Process non-blocking file transfer if one is active
       processFileTransfer();
       
       // Update system state
       systemState = STATE_ACTIVE;
    }

    // -----------------------------------------------------------------------
    // G. SD CARD DATA LOGGING - Writes once per second
    // -----------------------------------------------------------------------
    if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;
      
      if (myFile) {
        // Write timestamp and temperature to file
        // Format: "timestamp averageTemp" (e.g., "12345 8550")
        myFile.print(currentMillis);
        myFile.print(" ");
        myFile.println(AverageTemp);
        
        // Flush to ensure data is written to SD card
        myFile.flush();
      }
    }
  }  // End of LOOP_INTERVAL block
}  // End of loop()