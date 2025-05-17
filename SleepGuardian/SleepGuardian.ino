//-------------------------------------
// Assembly via Arduino - LCD Interface with SPI Debug
//-------------------------------------
#include <SPI.h>

// Define SPI debugging parameters
#define DEBUG_SPI_ENABLED   true
#define SERIAL_BAUD_RATE    9600

// SS pin is digital pin 10 (PB2) on Arduino Uno
#define SS_PIN              10

// SPI debugging statistics
struct SPIDebugStats {
  uint32_t requestCount;    // Total number of requests
  uint32_t successCount;    // Successful communications
  uint32_t failureCount;    // Failed communications 
  uint8_t lastDataSent;     // Last command byte sent
  uint8_t lastDataReceived; // Last byte received
  uint32_t startTime;       // System runtime at start (millis)
  uint32_t lastResponseTime; // Time for last response (microseconds)
};

// Global statistics instance
SPIDebugStats spiStats;

extern "C" {
  void master_main();
}

//----------------------------------------------------
void setup() {
  // Initialize Serial for debug output
  Serial.begin(SERIAL_BAUD_RATE);
  
  // Print welcome banner
  Serial.println("\n\n===========================");
  Serial.println("SleepGuardian Master v1.0");
  Serial.println("===========================");
  Serial.println("SPI Master - LCD Controller");
  Serial.println("SPI Debug Interface Enabled");
  Serial.println("----------------------------");
  
  // Initialize the debug statistics
  spiStats.requestCount = 0;
  spiStats.successCount = 0;
  spiStats.failureCount = 0;
  spiStats.lastDataSent = 0;
  spiStats.lastDataReceived = 0;
  spiStats.startTime = millis();
  spiStats.lastResponseTime = 0;
  
  // Print SPI pins
  Serial.println("SPI Pin Configuration:");
  Serial.print("MOSI: Pin "); Serial.println(MOSI);
  Serial.print("MISO: Pin "); Serial.println(MISO);
  Serial.print("SCK:  Pin "); Serial.println(SCK);
  Serial.print("SS:   Pin "); Serial.println(SS_PIN);
  Serial.println("----------------------------");
  
  // AUTO-START SPI MONITORING
  Serial.println("\n=== AUTO-STARTING SPI MONITORING ===");
  Serial.println("Capturing 10 seconds of SPI data...");
  Serial.println("----------------------------------");
  Serial.println("Time (ms) | Value (dec) | Value (hex) | Status");
  Serial.println("----------------------------------");
  
  unsigned long startMonitorTime = millis();
  
  // Run monitoring loop for 10 seconds
  while (millis() - startMonitorTime < 10000) { // 10 second monitoring period
    // Initialize SPI 
    pinMode(SS_PIN, OUTPUT);
    digitalWrite(SS_PIN, HIGH);
    SPI.begin();
    SPI.setClockDivider(SPI_CLOCK_DIV8);  // Try faster clock
    
    // Reset SPI flags before transfer
    SPSR; SPDR;  // Reading these registers clears flags
    
    // Request temperature data with proper timing
    digitalWrite(SS_PIN, HIGH);      // Ensure SS HIGH before starting
    delayMicroseconds(10);           // Short delay
    digitalWrite(SS_PIN, LOW);       // Select slave
    delayMicroseconds(100);          // Give slave plenty of time
    
    // Send command
    SPDR = 0x00;                     // Direct register access for command
    
    // Wait for transfer to complete
    while(!(SPSR & (1<<SPIF)));      // Wait for SPIF flag
    
    // Read result immediately
    uint8_t received = SPDR;
    
    // Deselect slave
    delayMicroseconds(10);
    digitalWrite(SS_PIN, HIGH);
    SPI.end();
    
    // Calculate time elapsed
    unsigned long timeElapsed = millis() - startMonitorTime;
    
    // Determine status
    String status;
    if (received == 0) {
      status = "ERROR: No response";
    } else if (received == 1) {
      status = "WARNING: Invalid data";
    } else if (received >= 2 && received < 100) {
      status = "Valid temperature";
    } else {
      status = "Unknown data";
    }
    
    // Print formatted data row
    Serial.print(timeElapsed);
    Serial.print("ms\t| ");
    Serial.print(received);
    Serial.print("\t| 0x");
    Serial.print(received, HEX);
    Serial.print("\t| ");
    Serial.println(status);
    
    delay(500); // Sample twice per second
  }
  
  Serial.println("\n=== SPI Monitoring Complete ===");
  Serial.println("Starting main system...");
  
  // Launch the assembly main function
  master_main();
}

//----------------------------------------------------
void loop() {
  // This function shouldn't be reached normally
  // But we can use it for debug terminal commands
  if (Serial.available() > 0) {
    char command = Serial.read();
    
    switch (command) {
      case 's':
        // Print statistics
        printSPIStats();
        break;
        
      case 'r':
        // Try an SPI transfer
        testSPITransfer();
        break;
        
      case 't':
        // Request temperature
        requestTemperature();
        break;
        
      case 'm':
        // Monitor SPI data continuously
        monitorSPIData();
        break;
        
      default:
        // Ignore other characters (like newlines, etc)
        break;
    }
  }
  
  // Optional: Periodically update SPI statistics if needed
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 5000) {  // Every 5 seconds
    lastUpdate = millis();
    if (DEBUG_SPI_ENABLED) {
      printSPIStats();
    }
  }
}

//----------------------------------------------------
// Print current SPI debug statistics
void printSPIStats() {
  Serial.println("\n--- SPI Debug Statistics ---");
  Serial.print("Runtime: ");
  Serial.print((millis() - spiStats.startTime) / 1000);
  Serial.println(" seconds");
  
  Serial.print("Total Requests: ");
  Serial.println(spiStats.requestCount);
  
  Serial.print("Successful: ");
  Serial.print(spiStats.successCount);
  Serial.print(" (");
  if (spiStats.requestCount > 0) {
    Serial.print(100 * spiStats.successCount / spiStats.requestCount);
  } else {
    Serial.print("0");
  }
  Serial.println("%)");
  
  Serial.print("Failed: ");
  Serial.println(spiStats.failureCount);
  
  Serial.print("Last Command Sent: 0x");
  Serial.print(spiStats.lastDataSent, HEX);
  Serial.print(" (");
  Serial.print(spiStats.lastDataSent);
  Serial.println(")");
  
  Serial.print("Last Data Received: 0x");
  Serial.print(spiStats.lastDataReceived, HEX);
  Serial.print(" (");
  Serial.print(spiStats.lastDataReceived);
  Serial.println(")");
  
  Serial.print("Last Response Time: ");
  Serial.print(spiStats.lastResponseTime);
  Serial.println(" μs");
  Serial.println("---------------------------");
}

//----------------------------------------------------
// Check if SPI slave is connected and responding
void checkSPISlaveConnection() {
  Serial.println("Checking SPI slave connection...");
  
  // Initialize SPI manually (since assembly will do it later)
  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);  // Ensure SS is HIGH initially
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV16);  // Slower speed for reliable debug
  
  // Try to communicate
  digitalWrite(SS_PIN, LOW);  // Select slave
  delayMicroseconds(100);     // Give slave time to prepare
  
  uint8_t received = SPI.transfer(0x00);  // Send command 0
  
  digitalWrite(SS_PIN, HIGH);  // Deselect slave
  
  // Check if we got valid data
  Serial.print("Received: 0x");
  Serial.print(received, HEX);
  Serial.print(" (");
  Serial.print(received);
  Serial.println(")");
  
  if (received > 0) {
    Serial.println("SPI slave is connected and responding!");
    
    // If temperature is readable, show it
    if (received >= 2 && received < 100) {
      Serial.print("Current temperature: ");
      Serial.print(received);
      Serial.println("°C");
    }
  } else {
    Serial.println("WARNING: SPI slave not responding or returning zero");
    Serial.println("Check connections and power to the slave device");
  }
  
  // End SPI (assembly code will reinitialize it)
  SPI.end();
  
  Serial.println("---------------------------");
}

//----------------------------------------------------
// Test SPI transfer to the slave with improved timing
void testSPITransfer() {
  Serial.println("\n=== SPI Transfer Test ===");
  
  // Initialize for manual test
  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);  // Ensure SS starts HIGH
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV8);  // Try faster clock for testing
  
  // Record the request
  spiStats.requestCount++;
  spiStats.lastDataSent = 0x00;  // Command 0 = request temperature
  
  // Multiple attempts for reliable data
  uint8_t received = 0;
  
  for (int attempt = 0; attempt < 3; attempt++) {
    // Reset SPI flags before transfer
    SPSR; SPDR;  // Reading these registers clears flags
    
    // Perform SPI transfer with proper timing
    digitalWrite(SS_PIN, HIGH);      // Ensure SS HIGH before starting
    delayMicroseconds(10);           // Short delay
    digitalWrite(SS_PIN, LOW);       // Select slave
    delayMicroseconds(100);          // Give slave plenty of time
    
    // Send command and measure time
    unsigned long startTime = micros();
    SPDR = 0x00;                     // Direct register access for command
    
    // Wait for transfer to complete
    while(!(SPSR & (1<<SPIF)));      // Wait for SPIF flag
    
    // Read result immediately after flag sets
    received = SPDR;
    spiStats.lastResponseTime = micros() - startTime;
    
    // Deselect slave
    delayMicroseconds(10);           // Short delay before deselect
    digitalWrite(SS_PIN, HIGH);
    
    // Check if response makes sense
    if (received >= 2 && received < 100) {
      break;  // Valid reading - exit retry loop
    }
    
    delay(5); // Short delay before retry
  }
  
  // Store result and update stats
  spiStats.lastDataReceived = received;
  
  // Print detailed SPI transfer results
  Serial.print("Command sent: 0x");
  Serial.println(spiStats.lastDataSent, HEX);
  Serial.print("Data received: 0x");
  Serial.print(received, HEX);
  Serial.print(" (");
  Serial.print(received);
  Serial.println(")");
  Serial.print("Response time: ");
  Serial.print(spiStats.lastResponseTime);
  Serial.println(" μs");
  
  // Check if response seems valid
  if (received >= 2) {
    spiStats.successCount++;
    Serial.print("SUCCESS! Temperature: ");
    Serial.print(received);
    Serial.println("°C");
  } else {
    spiStats.failureCount++;
    Serial.println("ERROR: Invalid temperature value");
  }
  
  // End SPI
  SPI.end();
  Serial.println("===========================");
}

//----------------------------------------------------
// Request temperature reading with improved timing
void requestTemperature() {
  Serial.println("Requesting temperature reading...");
  
  // Initialize for manual test
  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV16);
  
  // Record the request
  spiStats.requestCount++;
  spiStats.lastDataSent = 0x00;
  
  // Try up to 3 times (like assembly code does)
  uint8_t received = 0;
  bool success = false;
  
  for (int attempt = 0; attempt < 3; attempt++) {
    digitalWrite(SS_PIN, LOW);
    delayMicroseconds(100);
    
    received = SPI.transfer(0x00);
    
    digitalWrite(SS_PIN, HIGH);
    delayMicroseconds(50);
    
    // Check if we got a valid reading
    if (received >= 2) {
      success = true;
      break;
    }
    
    // Wait before retry
    delay(5);
  }
  
  // Store result
  spiStats.lastDataReceived = received;
  
  if (success) {
    spiStats.successCount++;
    Serial.print("Temperature: ");
    Serial.print(received);
    Serial.println("°C");
  } else {
    spiStats.failureCount++;
    Serial.println("Failed to get valid temperature reading");
    Serial.print("Last value received: ");
    Serial.println(received);
  }
  
  // End SPI
  SPI.end();
}

//----------------------------------------------------
// Continuously monitor SPI data from slave
void monitorSPIData() {
  Serial.println("\n=== Starting SPI Data Monitor ===");
  Serial.println("Press 'q' to quit monitoring");
  Serial.println("Sampling every 1 second...");
  Serial.println("----------------------------------");
  Serial.println("Time (s) | Value (dec) | Value (hex) | Status");
  Serial.println("----------------------------------");
  
  unsigned long startTime = millis();
  boolean monitoring = true;
  
  while (monitoring) {
    // Check for quit command
    if (Serial.available() > 0) {
      if (Serial.read() == 'q') {
        monitoring = false;
        break;
      }
    }
    
    // Initialize SPI 
    pinMode(SS_PIN, OUTPUT);
    digitalWrite(SS_PIN, HIGH);
    SPI.begin();
    SPI.setClockDivider(SPI_CLOCK_DIV16);
    
    // Request temperature data
    digitalWrite(SS_PIN, LOW);
    delayMicroseconds(100);
    
    uint8_t received = SPI.transfer(0x00);
    
    digitalWrite(SS_PIN, HIGH);
    SPI.end();
    
    // Calculate time elapsed
    unsigned long timeElapsed = (millis() - startTime) / 1000;
    
    // Determine status
    String status;
    if (received == 0) {
      status = "ERROR: No response";
    } else if (received == 1) {
      status = "WARNING: Invalid data";
    } else if (received >= 2 && received < 100) {
      status = "Valid temperature";
    } else {
      status = "Unknown data";
    }
    
    // Print formatted data row
    Serial.print(timeElapsed);
    Serial.print("s\t| ");
    Serial.print(received);
    Serial.print("\t| 0x");
    Serial.print(received, HEX);
    Serial.print("\t| ");
    Serial.println(status);
    
    delay(1000); // Sample every second
  }
  
  Serial.println("\n=== SPI Monitoring Stopped ===");
}