//-------------------------------------
// Assembly via Arduino - SleepGuardian
//-------------------------------------
#include <Arduino.h>

// Debug function to print RTC values via Serial
extern "C" void debugPrintDateTime(uint8_t seconds, uint8_t minutes, uint8_t hours, 
                                  uint8_t day, uint8_t date, uint8_t month, uint8_t year) {
  static char timeStr[50];
  
  // Convert BCD values to decimal
  uint8_t sec_dec = (seconds & 0x0F) + ((seconds >> 4) & 0x07) * 10;
  uint8_t min_dec = (minutes & 0x0F) + ((minutes >> 4) & 0x07) * 10;
  uint8_t hour_dec = (hours & 0x0F) + ((hours >> 4) & 0x03) * 10;
  uint8_t day_dec = day; // Day of week is not BCD
  uint8_t date_dec = (date & 0x0F) + ((date >> 4) & 0x03) * 10;
  uint8_t month_dec = (month & 0x0F) + ((month >> 4) & 0x01) * 10;
  uint8_t year_dec = (year & 0x0F) + ((year >> 4) & 0x0F) * 10;
  
  // Create formatted time string
  sprintf(timeStr, "[RTC DEBUG] Time: %02d:%02d:%02d Date: %02d/%02d/20%02d Day: %d", 
          hour_dec, min_dec, sec_dec, month_dec, date_dec, year_dec, day_dec);
  
  // Print to serial
  Serial.println(timeStr);
}

extern "C"
{
  void sleepguardian_main();
}

//----------------------------------------------------
void setup()
{
  // Initialize serial for debug messages (assembly code will use this)
  Serial.begin(9600);
  Serial.println("SleepGuardian Starting...");
  
  // Call the main assembly function that takes over all functionality
  sleepguardian_main();
}

//----------------------------------------------------
void loop() 
{
  // Empty - all functionality is in assembly
}