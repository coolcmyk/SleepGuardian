
# SleepGuardian 😴🔒

SleepGuardian adalah sistem alarm pintar berbasis mikrokontroler ATmega328P yang dirancang untuk memastikan pengguna benar-benar memasuki kondisi tidur setelah alarm menyala. Berbeda dari alarm konvensional, alarm ini tidak dapat dimatikan hanya dengan satu tombol. Sistem memverifikasi keberadaan dan kondisi tidur pengguna melalui gabungan sensor. Alarm hanya dapat dimatikan jika semua kondisi terpenuhi secara bersamaan. Setelah alarm berhasil dimatikan, sistem akan otomatis mengaktifkan mode siaga dan kembali membunyikan alarm ketika user kembali mengaktifkan alat Alarm buatan ini


---

## 📌 Features

- 🧠 Smart verification to detect sleep state
- 🔄 Cannot be silenced with a single button press
- 📟 Sensor-based monitoring (e.g., motion, heart rate, or eye state depending on sensors)
- 🛑 Alarm only stops when all sleep verification conditions are satisfied
- 🔁 Automatically reactivates if user re-engages system
- 🧪 Designed and tested using **Proteus simulation**

---

## 🛠️ Components

- **ATmega328P** Microcontroller
- Sensor modules (e.g., motion, pulse, IR for eye detection)
- Buzzer or speaker module
- Button interface (optional for secondary interactions)
- **Proteus simulation** file for virtual testing

---

## 🧾 Project Structure

```plaintext
SleepGuardian/
├── SleepGuardian.ino          # Main Arduino sketch
├── sleep_check.S              # Assembly file for low-level operations
├── proteus/                   # Folder containing .pdsprj and related simulation files
│   └── SleepGuardian.pdsprj   # Proteus project file
├── README.md                  # This file
└── docs/                      # (Optional) For extra documentation and schematics
````

---

## 🚀 Getting Started

### 1. **Simulation**

* Open `proteus/SleepGuardian.pdsprj` in Proteus.
* Ensure your sensor models and ATmega328P are configured.
* Start the simulation to test alarm logic.

### 2. **Flashing to Device**

* Compile `SleepGuardian.ino` in Arduino IDE.
* Ensure the `.S` file is correctly linked or called within the `.ino` via `asm` or linked script.
* Upload the code to ATmega328P (on Arduino Uno or standalone).

### 3. **Sensors Setup**

Ensure your hardware setup includes the required sensors. The alarm system depends on correct readings to determine sleep state.

---

## 🧠 How It Works

1. Alarm activates at the scheduled time.
2. System checks:

   * Is the user in bed?
   * Is there minimal movement?
   * Are biological signals (e.g., pulse) indicating sleep state?
3. Only if **all conditions are true**, alarm stops.
4. Otherwise, continues alerting.

---

## 🧰 Tools Used

* Arduino IDE
* Proteus Design Suite
* AVR Assembly for performance-critical operations

---

---

Would you like me to generate a Proteus schematic or a project diagram too?
```
