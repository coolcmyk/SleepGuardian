// Smart Alarm System
// Interrupt handler in C, main logic in Assembly (finpro.S)

// Function prototypes for assembly functions (defined in finpro.S)
extern "C" {
  void setup_ports(void);
  void init_serial(void);
  void main_logic(void);
}

// Global flag for reset button interrupt
volatile uint8_t reset_flag = 0;

void setup() {
  // Initialize ports (defined in assembly)
  setup_ports();
  
  // Initialize serial communication (defined in assembly)
  init_serial();
  
  // Set up external interrupt INT0 (PD2) for reset button
  // Configure INT0 to trigger on falling edge
  EICRA |= (1 << ISC01); // Falling edge of INT0
  EICRA &= ~(1 << ISC00);
  
  // Enable external interrupt INT0
  EIMSK |= (1 << INT0);
  
  // Enable global interrupts
  sei();
}

void loop() {
  // Call main logic function from assembly
  main_logic();
  
  // Check if reset was triggered by interrupt
  if (reset_flag) {
    // Reset system state
    reset_flag = 0;
    
    // Send reset message through Serial
    Serial.begin(9600);
    Serial.println("System Reset by Interrupt");
    Serial.flush();
  }
}

// Interrupt Service Routine for INT0 (Reset Button)
ISR(INT0_vect) {
  // Set reset flag
  reset_flag = 1;
  
  // Turn off buzzer (PB5)
  PORTB &= ~(1 << PB5);
  
  // Turn off red LED (PD3)
  PORTD &= ~(1 << PD3);
}