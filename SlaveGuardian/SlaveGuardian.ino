//-------------------------------------
// SleepGuardian SPI-Slave + DHT11
//-------------------------------------
#include <SPI.h>

// Global variable to store temperature value
volatile uint8_t currentTemperature = 42;  // Initial value 42 (clearly distinct from 01)
volatile bool debugMode = true;            // Enable debug output

// External assembly functions
extern "C" {
  void slave_main();
  void setTemperature(uint8_t temp);
  uint8_t getTemperature();
  void printDebug(const char* msg);
}

// Function to print debug messages via serial
void printDebug(const char* msg) {
  if (debugMode) {
    Serial.println(msg);
  }
}

// Function to be called from assembly to set temperature
void setTemperature(uint8_t temp) {
  if (debugMode) {
    Serial.print("DHT11 Read: ");
    Serial.print(temp);
    Serial.println("C");
  }
  
  currentTemperature = temp;
  
  // Ensure data is ready for next transfer
  SPDR = currentTemperature;
}

// Function to get temperature value
uint8_t getTemperature() {
  return currentTemperature;
}

// SPI interrupt service routine
ISR(SPI_STC_vect) {
  // Read incoming byte (command byte)
  byte receivedByte = SPDR;
  
  // Always respond with temperature no matter what command
  SPDR = currentTemperature;

  // Print more detailed debug info for Proteus Virtual Terminal
  if (debugMode) {
    Serial.print("SPI transfer: received CMD=");
    Serial.print(receivedByte, HEX);
    Serial.print(", sent TEMP=");
    Serial.println(currentTemperature);
  }
}

// Print numeric value with description
void printValue(const char* label, int value) {
  if (debugMode) {
    Serial.print(label);
    Serial.print(": ");
    Serial.println(value);
  }
}

void setup() {
  // Initialize serial communication for Virtual Terminal
  Serial.begin(9600);
  
  // Show startup banner in Virtual Terminal
  Serial.println("\n\n===========================");
  Serial.println("SleepGuardian Slave v1.0");
  Serial.println("===========================");
  Serial.println("DHT11 Temperature Sensor");
  Serial.println("SPI Communication Interface");
  Serial.println("----------------------------");
  
  // Manually set pins for SPI
  pinMode(MISO, OUTPUT);
  pinMode(MOSI, INPUT);
  pinMode(SCK, INPUT);
  pinMode(SS, INPUT);
  
  // Initialize SPI in slave mode with interrupt
  SPCR = (1 << SPE) | (1 << SPIE);
  
  // Print configured status
  Serial.println("SPI Pins Configured:");
  Serial.print("MISO: Pin "); Serial.println(MISO);
  Serial.print("MOSI: Pin "); Serial.println(MOSI);
  Serial.print("SCK:  Pin "); Serial.println(SCK);
  Serial.print("SS:   Pin "); Serial.println(SS);
  Serial.println("----------------------------");
  
  // Show terminal operation instructions  
  Serial.println("Starting sensor readings...");
  Serial.println("Temperatures will be displayed below:");
  
  // Call assembly main function (blocking function)
  slave_main();
}

void loop() {
  // This should never be reached
}
