#include <Adafruit_NeoPixel.h>
#include <Adafruit_MLX90614.h>
#include <ArduinoBLE.h>
#include <SD.h> 

// --- CONFIGURATION ---
#define Lower_Limit 7000  
#define Upper_Limit 9800  
#define PIN A1            
#define motor_pin A3      
#define NUMPIXELS 7       
#define MAX_LINE_LENGTH 80
#define BREATH_PIN A0
#define LOOP_INTERVAL 20  

Adafruit_NeoPixel pixels(NUMPIXELS, PIN, NEO_GRB + NEO_KHZ800);
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// --- BLE UUIDs ---
BLEService radarService("87f23fe2-4b42-11ed-bdc3-0242ac120000"); 

BLEStringCharacteristic temperatureCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000A", BLERead | BLENotify, 20);
BLEStringCharacteristic brightnessCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000B", BLERead | BLENotify | BLEWrite, 20);
BLEStringCharacteristic inBreathTimeCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000C", BLERead | BLENotify | BLEWrite, 20);
BLEStringCharacteristic outBreathTimeCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000D", BLERead | BLENotify | BLEWrite, 20);
BLEStringCharacteristic motorStrengthCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac12000E", BLERead | BLENotify | BLEWrite, 20);
BLEStringCharacteristic fileListRequestChar("87f23fe2-4b42-11ed-bdc3-0242ac12000F", BLEWrite, 20);
BLEStringCharacteristic fileNameChar("87f23fe2-4b42-11ed-bdc3-0242ac120010", BLERead | BLENotify, 20);
BLEStringCharacteristic fileContentRequestChar("87f23fe2-4b42-11ed-bdc3-0242ac120011", BLEWrite, 32);
BLEStringCharacteristic fileContentChar("87f23fe2-4b42-11ed-bdc3-0242ac120012", BLERead | BLENotify, MAX_LINE_LENGTH);
BLEStringCharacteristic fileActionChar("87f23fe2-4b42-11ed-bdc3-0242ac120013", BLEWrite, 32);
BLEStringCharacteristic sessionIdCharacteristic("87f23fe2-4b42-11ed-bdc3-0242ac120014", BLERead | BLENotify, 10);

// --- COLOR ARRAYS ---
const float ColorArray[14][3] = {
  { 0.25, 0.25, 0.25 }, { 0.3, 0, 0.3 }, { 0.95, 0, 0 }, { 0.95, 0.15, 0 },
  { 0.95, 0.45, 0 }, { 1, 1, 0 }, { 0.35, 1, 0 }, { 0, 1, 0.02 },
  { 0, 1, 0.2 }, { 0, 1, 1 }, { 0, 0.125, 1 }, { 0.15, 0, 1 },
  { 0.6, 0, 1 }, { 1, 1, 1 }
};

float ColorArraySetup[6][3] = {
  { 0.8, 0, 0 }, { 0.4, 0, 0.8 }, { 0, 0, 1 }, 
  { 0, 0.5, 0.7 }, { 0, 1, 0 }, { 0, 0, 0 }
}; 

// --- VARIABLES ---
const int NumberOfColors = sizeof(ColorArray) / sizeof(ColorArray[0]);
float OneColorRange = (Upper_Limit - Lower_Limit) / (NumberOfColors - 1);
int color1, color2;
int color1_index, color2_index;

const int NumOfPoints = 50;
int tempBuffer[NumOfPoints] = {0};
int tempBufferIndex = 0;
long tempRunningSum = 0; 

float MotorStrength = 150; 
float Brightness = 0;
float MaxBrightness = 125;
float BreathPacer;
float BreathTimer = 0;
float InbreathTime = 4500; 
float OutbreathTime = 9000;  
float BreathCycleTime = InbreathTime + OutbreathTime;

bool vibration = 0;
unsigned long vibration_start = 0;
int no_vibration_count = 0;
int NumberOfLedsOn = 0;
int previous_num_led_on = 0;
bool vibration_progress[NumberOfColors * 6];

bool cancelRequested = false;
bool wasConnected = false; // BLE State tracking

// SD Card Variables
const int chipSelect = D7;  
File myFile;
int fileNumber = 0; 
unsigned long previousMillis = 0; 
const long interval = 1000; 
char fileNameBuffer[20]; 

// Timing Variables
unsigned long lastLoopTime = 0;
unsigned long lastTempSendTime = 0; // Debug: track temp send timing

// --- FUNCTIONS ---

int GetOptimizedAverage(int newTemp) {
  if (newTemp <= 0 || newTemp > 20000) {
     if (tempRunningSum > 0) return tempRunningSum / NumOfPoints;
     return newTemp;
  }
  tempRunningSum -= tempBuffer[tempBufferIndex];
  tempBuffer[tempBufferIndex] = newTemp;
  tempRunningSum += newTemp;
  tempBufferIndex++;
  if (tempBufferIndex >= NumOfPoints) tempBufferIndex = 0;
  return tempRunningSum / NumOfPoints;
}

int getNextSessionId() {
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

  int maxNum = -1;
  File root = SD.open("/");
  if (root) {
    File entry = root.openNextFile();
    while (entry) {
      String name = entry.name();
      String lname = name;
      lname.toLowerCase();

      if (lname.startsWith("data") && lname.endsWith(".txt")) {
        String numStr = lname.substring(4, lname.length() - 4);
        int n = numStr.toInt();
        maxNum = max(maxNum, n);
      }
      entry.close();
      entry = root.openNextFile();
    }
    root.close();
  }
  return maxNum + 1;
}

void saveNextSessionIdCache(int nextId) {
  if (SD.exists("nextsid.txt")) {
    SD.remove("nextsid.txt");
  }
  File cache = SD.open("nextsid.txt", FILE_WRITE);
  if (cache) {
    cache.println(nextId);
    cache.close();
  }
}

void startNewSession() {
  Serial.println("BLE DEBUG: startNewSession() called");
  
  if (myFile) {
    myFile.close();
    Serial.println("BLE DEBUG: Closed previous file");
  }

  fileNumber = getNextSessionId();
  Serial.print("BLE DEBUG: Got SessionID: ");
  Serial.println(fileNumber);
  
  snprintf(fileNameBuffer, sizeof(fileNameBuffer), "data%d.txt", fileNumber);
  Serial.print("BLE DEBUG: Opening file: ");
  Serial.println(fileNameBuffer);

  myFile = SD.open(fileNameBuffer, FILE_WRITE);
  if (myFile) {
    saveNextSessionIdCache(fileNumber + 1);
    Serial.println("BLE DEBUG: File opened successfully");
  } else {
    Serial.println("BLE DEBUG: ERROR - Failed to open file!");
  }
  
  // Send SessionID via BLE notification
  String sidStr = String(fileNumber);
  Serial.print("BLE DEBUG: Sending SessionID notification: '");
  Serial.print(sidStr);
  Serial.println("'");
  
  sessionIdCharacteristic.setValue(sidStr);
  
  // Give BLE stack time to send the notification
  unsigned long start = millis();
  while (millis() - start < 50) { BLE.poll(); }
  
  Serial.println("BLE DEBUG: SessionID notification sent");
}

void setup() {
  Serial.begin(115200);
  // Wait for serial so we can see startup BLE logs, timeout after 2s if no USB
  while (!Serial && millis() < 2000); 

  pinMode(motor_pin, OUTPUT);
  pinMode(BREATH_PIN, OUTPUT);
  digitalWrite(BREATH_PIN, LOW);

  mlx.begin();
  
  pixels.begin();
  pixels.clear();
  pixels.show();

  for(int i=0; i<NumOfPoints; i++) tempBuffer[i] = 0;

  if (SD.begin(chipSelect)) {
    startNewSession(); 
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

  if (!BLE.begin()) {
    Serial.println("BLE DEBUG: BLE Hardware Init Failed!");
    while(1);
  }
  
  BLE.setDeviceName("Calmwand 2C");
  BLE.setLocalName("Calmwand 2C");
  BLE.setAdvertisedService(radarService);

  radarService.addCharacteristic(temperatureCharacteristic); 
  radarService.addCharacteristic(brightnessCharacteristic);  
  radarService.addCharacteristic(inBreathTimeCharacteristic);  
  radarService.addCharacteristic(outBreathTimeCharacteristic);  
  radarService.addCharacteristic(motorStrengthCharacteristic); 
  radarService.addCharacteristic(fileListRequestChar);
  radarService.addCharacteristic(fileNameChar);
  radarService.addCharacteristic(fileContentRequestChar);
  radarService.addCharacteristic(fileContentChar);
  radarService.addCharacteristic(fileActionChar);
  radarService.addCharacteristic(sessionIdCharacteristic);

  BLE.addService(radarService);
  BLE.advertise();
  
  // INITIAL BLE CONFIG VALUES
  brightnessCharacteristic.setValue(String(MaxBrightness));
  inBreathTimeCharacteristic.setValue(String(InbreathTime));
  outBreathTimeCharacteristic.setValue(String(OutbreathTime));
  motorStrengthCharacteristic.setValue(String(MotorStrength));

  for (int i = 0; i < NumberOfColors * 6; i++) {
    vibration_progress[i] = 0;
  } 
  
  BreathTimer = millis();
  Serial.println("BLE DEBUG: System Ready. Advertising started.");
}

int ConvertRGBtoInt(float RGBValues[3], float brightnessVal) {
  int R = round(brightnessVal * (RGBValues[0]));
  int G = round(brightnessVal * (RGBValues[1]));
  int B = round(brightnessVal * (RGBValues[2]));
  return pixels.Color(R, G, B);
};

void DetermineColors(float Temp, int Colors[2]) {
  for (int i = 0; i < NumberOfColors; i++) {
    if (Temp < Lower_Limit) {
      color1_index = 0; color2_index = 0; break;
    } else if (Temp < Lower_Limit + (i + 1) * OneColorRange) {
      color1_index = i; color2_index = i + 1; break;
    } else if (Temp > Upper_Limit) {
      color1_index = NumberOfColors - 1; color2_index = NumberOfColors - 1; break;
    }
  }
  Colors[0] = color1_index;
  Colors[1] = color2_index;
}

int DetermineNumberofLedsOn(float Temp, int currentLedsOn) {
  float baseline = Temp - Lower_Limit;
  float remainder = fmod(baseline, OneColorRange);
  float OneLedRange = OneColorRange / 6;
  float threshold = 0.5 * OneLedRange;

  int numLeds = static_cast<int>(remainder / OneLedRange);

  if (numLeds < currentLedsOn) {
    if (remainder > (numLeds + 1) * OneLedRange - threshold) {
      numLeds = currentLedsOn; 
    }
  }
  return min(7, max(numLeds, 0));
}

void sendFileContent(const String &filename) {
  Serial.print("BLE DEBUG: >> Sending file content: "); Serial.println(filename);
  
  File f = SD.open(filename, FILE_READ);
  if (!f) {
    Serial.println("BLE DEBUG: >> Error: File not found on SD.");
    return;
  }

  cancelRequested = false;
  unsigned long byteCount = 0;
  
  while (f.available()) {
    BLE.poll(); 
    if (cancelRequested) {
      Serial.println("BLE DEBUG: >> Transfer Cancelled by Central.");
      break;
    }

    String line = f.readStringUntil('\n');
    byteCount += line.length();
    
    if (line.length() > 0) {
      fileContentChar.setValue(line);
      unsigned long start = millis();
      while (millis() - start < 10) { BLE.poll(); }
    }
  }
  f.close();
  
  if (!cancelRequested) {
    Serial.print("BLE DEBUG: >> Transfer Complete. Bytes sent: "); Serial.println(byteCount);
    fileContentChar.setValue("EOF");
    delay(10);
  }
}

void handleBleCommands() {
  
  if (brightnessCharacteristic.written()) {
    float val = brightnessCharacteristic.value().toFloat();
    Serial.print("BLE DEBUG: Write Brightness: "); Serial.println(val);
    MaxBrightness = constrain(val, 0, 255);
    
    SD.remove("config.txt");
    File cfg = SD.open("config.txt", FILE_WRITE);
    if (cfg) { cfg.println((int)MaxBrightness); cfg.close(); }
    brightnessCharacteristic.setValue(String(MaxBrightness));
  }
  
  if (inBreathTimeCharacteristic.written()) {
    InbreathTime = inBreathTimeCharacteristic.value().toFloat(); 
    BreathCycleTime = InbreathTime + OutbreathTime;
    Serial.print("BLE DEBUG: Write InBreath: "); Serial.println(InbreathTime);
    inBreathTimeCharacteristic.setValue(String(InbreathTime));
  }

  if (outBreathTimeCharacteristic.written()) {
    OutbreathTime = outBreathTimeCharacteristic.value().toFloat();
    BreathCycleTime = InbreathTime + OutbreathTime;
    Serial.print("BLE DEBUG: Write OutBreath: "); Serial.println(OutbreathTime);
    outBreathTimeCharacteristic.setValue(String(OutbreathTime));
  }

  if (motorStrengthCharacteristic.written()) {
    MotorStrength = constrain(motorStrengthCharacteristic.value().toFloat(), 0, 255);
    Serial.print("BLE DEBUG: Write Motor: "); Serial.println(MotorStrength);
    motorStrengthCharacteristic.setValue(String(MotorStrength));
  }
  
  if (fileListRequestChar.written()) {
    if (fileListRequestChar.value() == "GETLIST") {
       Serial.println("BLE DEBUG: Command GETLIST received.");
       File root = SD.open("/");
       if (root) {
         File entry = root.openNextFile();
         while (entry) {
           if (!entry.isDirectory()) {
             String fname = String(entry.name());
             int sid = fname.substring(4, fname.length() - 4).toInt(); 
             
             unsigned long fsize = entry.size();
             int estimatedMins = (fsize / 14) / 60;
             if (estimatedMins < 1) estimatedMins = 1; 
             
             String out = String(sid) + ":" + fname + ":" + String(estimatedMins); 
             
             fileNameChar.setValue(out);
             Serial.print("BLE DEBUG: Listing File -> "); Serial.println(out);
             
             unsigned long start = millis();
             while (millis() - start < 15) { BLE.poll(); }
           }
           entry.close();
           entry = root.openNextFile();
         }
         root.close();
         
         fileNameChar.setValue("END");
         Serial.println("BLE DEBUG: End of File List.");
         
         unsigned long start = millis();
         while (millis() - start < 20) { BLE.poll(); } 
       } else {
         Serial.println("BLE DEBUG: SD Root open failed.");
       }
    }
  }

  if (fileContentRequestChar.written()) {
    String cmd = fileContentRequestChar.value();
    Serial.print("BLE DEBUG: Content Req: "); Serial.println(cmd);
    
    if (cmd.startsWith("GETFILE:")) {
      String filename = cmd.substring(8);
      filename.trim();
      sendFileContent(filename);
    }
    else if (cmd == "CANCEL") { 
      cancelRequested = true; 
      Serial.println("BLE DEBUG: Cancel Flag Set.");
    }
    else if (cmd.startsWith("DELETE:")) {
      String filename = cmd.substring(7);
      filename.trim();
      if (SD.exists(filename)) {
        SD.remove(filename);
        if (SD.exists("nextsid.txt")) SD.remove("nextsid.txt");
        Serial.print("BLE DEBUG: File Deleted: "); Serial.println(filename);
      } else {
        Serial.print("BLE DEBUG: Delete failed, file missing: "); Serial.println(filename);
      }
    }
  }

  if (fileActionChar.written()) {
    String cmd = fileActionChar.value();
    Serial.print("BLE DEBUG: Action Req: "); Serial.println(cmd);
    
    if (cmd == "START") {
      startNewSession();
      Serial.println("BLE DEBUG: New Session Started via BLE.");
    } else if (cmd.startsWith("DELETE:")) {
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

// --- MAIN LOOP ---
void loop() {
  BLE.poll();

  // --- BLE CONNECTION TRACKING ---
  BLEDevice central = BLE.central();
  if (central) {
    if (!wasConnected) {
      Serial.print("BLE DEBUG: Device Connected. Address: ");
      Serial.println(central.address());
      wasConnected = true;
    }
    // Handle commands only when connected
    handleBleCommands();
  } else {
    if (wasConnected) {
      Serial.println("BLE DEBUG: Device Disconnected.");
      wasConnected = false;
    }
  }

  unsigned long currentMillis = millis();

  if (currentMillis - lastLoopTime >= LOOP_INTERVAL) {
    lastLoopTime = currentMillis;

    // A. Read Sensor & Avg
    int rawTemp = 100 * mlx.readObjectTempF();
    float AverageTemp = GetOptimizedAverage(rawTemp);
    
    // B. Breath Logic
    BreathPacer = currentMillis - BreathTimer;
    
    if (BreathPacer < InbreathTime) {
      Brightness = MaxBrightness * pow((BreathPacer / InbreathTime), 2);
      digitalWrite(BREATH_PIN, HIGH);
      pixels.setPixelColor(0, pixels.Color(0, 20, 0)); 
    } 
    else if (BreathPacer < BreathCycleTime) {
      float progress = BreathPacer - InbreathTime;
      Brightness = MaxBrightness * pow(-(progress - OutbreathTime) / OutbreathTime, 2);
      digitalWrite(BREATH_PIN, LOW);
      pixels.setPixelColor(0, 0); 
    } 
    else {
      BreathTimer = currentMillis; 
    }

    // C. Determine Colors & LEDs
    int Colors[2];
    DetermineColors(AverageTemp, Colors);
    NumberOfLedsOn = DetermineNumberofLedsOn(AverageTemp, NumberOfLedsOn);

    // D. Vibration Logic
    int currentLedIndex = color1_index * 6 + NumberOfLedsOn;
    
    if ((NumberOfLedsOn > previous_num_led_on || (NumberOfLedsOn == 0 && previous_num_led_on == 5)) 
        && vibration_progress[currentLedIndex] == 0) {
      vibration = 1;
      vibration_start = currentMillis;
      for (int i = 0; i <= currentLedIndex; i++) { vibration_progress[i] = 1; }
    }

    if (NumberOfLedsOn == previous_num_led_on && !vibration) {
      no_vibration_count++;
      if (no_vibration_count >= 10) { 
        for (int i = 0; i < NumberOfColors * 6; i++) { vibration_progress[i] = 0; }
        no_vibration_count = 0; 
      }
    } else {
      no_vibration_count = 0;
    }

    if (vibration) {
      analogWrite(motor_pin, MotorStrength);
      if (currentMillis - vibration_start > 300) { 
        vibration = 0; 
      }
    } else {
      analogWrite(motor_pin, 0);
    }
    previous_num_led_on = NumberOfLedsOn;

    // E. Set Pixels
    color1 = ConvertRGBtoInt((float*)ColorArray[Colors[0]], Brightness);
    color2 = ConvertRGBtoInt((float*)ColorArray[Colors[1]], Brightness);

    for (int i = 1; i <= NumberOfLedsOn; i++) { pixels.setPixelColor(i, color2); }
    for (int i = NumberOfLedsOn + 1; i < 7; i++) { pixels.setPixelColor(i, color1); }
    pixels.show();

    // F. Send BLE Data - use wasConnected flag for reliability
    if (wasConnected) {
       String tempStr = String(AverageTemp); 
       temperatureCharacteristic.setValue(tempStr);
       
       // Debug: Print every 500ms to avoid flooding serial
       if (currentMillis - lastTempSendTime >= 500) {
         lastTempSendTime = currentMillis;
         Serial.print("BLE TX: Temp=");
         Serial.print(tempStr);
         Serial.print(" | Raw=");
         Serial.print(rawTemp);
         Serial.print(" | Connected=");
         Serial.println(wasConnected ? "YES" : "NO");
       }
    }

    // G. SD Logging
    if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;
      if (myFile) {
        myFile.print(currentMillis);
        myFile.print(" ");
        myFile.println(AverageTemp);
        myFile.flush();
      }
    }
  }
}