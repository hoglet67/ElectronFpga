/**
 * Firmware for the ATSAMD11C14A chip on board the Ultimate Electron Upgrade board.
 *
 * This chip will probably not be on later versions, once the FPGA's USB port is
 * working.  Right now it provides a convenient USB debug interface, and access to
 * the flash.
 */

/*

  Partly derived from code under the following license:

  Copyright (c) 2015 Arduino LLC.  All right reserved.
  Copyright (c) 2017 MattairTech LLC. All right reserved.

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <SPI.h>

/*
 * FPGA serial port
 *
 * TXD = PA14 sercom2.0  **** D11C doesn't have SERCOM2!
 * RXD = PA15 sercom2.1
 */
#define TXD_PIN 14
#define RXD_PIN 15

/*
 * FPGA SPI port:
 *
 * MISO = PA09 sercom0.3 (alt)
 * SCK  = PA05 sercom0.1 (alt)
 * MOSI = PA04 sercom0.0 (alt)
 * SS   = PA08 sercom0.2 (alt)
 */

#define FPGA_MISO_PIN 9
#define FPGA_SCK_PIN  5
#define FPGA_MOSI_PIN 4
#define FPGA_SS_PIN   8

SPIClass fpga_spi(&sercom0, FPGA_MISO_PIN, FPGA_SCK_PIN, FPGA_MOSI_PIN, SPI_PAD_0_SCK_1, SERCOM_RX_PAD_3);

// Derived from pinPeripheral() in wiring_private.c
void setup_pin(int pinNum, int peripheral) {

  noInterrupts(); // Avoid possible invalid interim pin state

  uint8_t pinCfg = (PORT->Group[PORTA].PINCFG[pinNum].reg & PORT_PINCFG_PULLEN);   // Preserve state of pullup/pulldown enable, clear the rest of the bits

  if ( pinNum & 1 ) // is pin odd?
  {
    // Get whole current setup for both odd and even pins and remove odd one, then set new muxing
    uint32_t temp = (PORT->Group[PORTA].PMUX[pinNum >> 1].reg) & PORT_PMUX_PMUXE( 0xF ) ;
    PORT->Group[PORTA].PMUX[pinNum >> 1].reg = temp|PORT_PMUX_PMUXO( peripheral ) ;
  }
  else // even pin
  {
    // Get whole current setup for both odd and even pins and remove even one, then set new muxing
    uint32_t temp = (PORT->Group[PORTA].PMUX[pinNum >> 1].reg) & PORT_PMUX_PMUXO( 0xF ) ;
    PORT->Group[PORTA].PMUX[pinNum >> 1].reg = temp|PORT_PMUX_PMUXE( peripheral ) ;
  }

  pinCfg |= PORT_PINCFG_PMUXEN; // Enable peripheral mux

  // Set pin drive strength, enable/disable pull resistor, enable/disable INEN, and enable/disable the peripheral mux
  PORT->Group[PORTA].PINCFG[pinNum].reg = (uint8_t)pinCfg ;

  interrupts();
}

void setup() {
  Serial.begin(9600);

  pinMode(FPGA_SS_PIN, OUTPUT);
  digitalWrite(FPGA_SS_PIN, HIGH);
  fpga_spi.begin();
  setup_pin(FPGA_MOSI_PIN, PER_SERCOM_ALT);
  setup_pin(FPGA_SCK_PIN,  PER_SERCOM_ALT);
  setup_pin(FPGA_MISO_PIN, PER_SERCOM_ALT);
  // 1MHz for debugging so I can easily catch it on a logic analyzer
  // fpga_spi.beginTransaction(SPISettings(1000000L, MSBFIRST, SPI_MODE0));
  // 12MHz doesn't work yet, so 8 will have to do...
  fpga_spi.beginTransaction(SPISettings(8000000L, MSBFIRST, SPI_MODE0));

  // Serial port (TBD)
  // pinMode(TXD_PIN, OUTPUT);
  // digitalWrite(TXD_PIN, HIGH);
  // pinMode(RXD_PIN, INPUT);
}

uint8_t debug_transfer(uint8_t b) {
  Serial.print("[tx ");
  Serial.print(b, HEX);
  b = fpga_spi.transfer(b);
  Serial.print(" rx ");
  Serial.print(b, HEX);
  Serial.print("]");
  return b;
}

// Uncomment this for super verbose debugging
// #define fpga_spi_transfer debug_transfer
#define fpga_spi_transfer fpga_spi.transfer

static boolean spi_started = false;

static void start_spi(uint8_t cmd) {
  if (spi_started) {
    Serial.println("Attempt to start SPI when already started!");
    while (1);
  }
  spi_started = true;

  digitalWrite(FPGA_SS_PIN, LOW);

  fpga_spi_transfer(cmd);
}

static void flash_start_spi(uint8_t cmd) {
  // Init passthrough to flash
  start_spi(0x02);

  // Send command
  fpga_spi_transfer(cmd);
}

static void end_spi() {
  if (!spi_started) {
    Serial.println("Attempt to end SPI when not started!");
    while (1);
  }
  spi_started = false;

  digitalWrite(FPGA_SS_PIN, HIGH);
}

static void enter_passthrough() {
  start_spi(1);  // config passthrough
  fpga_spi_transfer(0x01);  // passthrough active
  end_spi();
  delay(1);
}

static void exit_passthrough() {
  start_spi(1);  // config passthrough
  fpga_spi_transfer(0x00);  // passthrough off
  end_spi();
  delay(1);
}

// Erase/write in progress
#define STATUS1_BUSY 0x01
// Quad IO enable bit in status 2 register
#define STATUS2_QE 0x02

uint8_t read_status1() {
  flash_start_spi(0x05);
  uint8_t status1 = fpga_spi_transfer(0);
  end_spi();
  return status1;
}

uint8_t read_status2() {
  flash_start_spi(0x35);
  uint8_t status2 = fpga_spi_transfer(0);
  end_spi();
  return status2;
}

boolean flash_busy() {
  uint8_t r = read_status1() & STATUS1_BUSY;
  // if (r) Serial.println("BUSY!");
  return r;
}

static void flash_end_spi_after_write() {
  end_spi();
  while (flash_busy());
  // Flash write is automatically disabled; we don't need to call flash_write_disable() now.
}

void flash_write_enable() {
  flash_start_spi(0x06);
  end_spi();
}

void flash_write_disable() {
  flash_start_spi(0x04);
  end_spi();
}

void flash_send_24bit_addr(uint32_t addr) {
  fpga_spi_transfer((uint8_t)((addr & 0xff0000L) >> 16));
  fpga_spi_transfer((uint8_t)((addr & 0xff00L) >> 8));
  fpga_spi_transfer((uint8_t)(addr & 0xffL));
}

void erase_sector(uint32_t addr) {
  flash_write_enable();
  flash_start_spi(0x20);  // Sector erase
  flash_send_24bit_addr(addr);
  flash_end_spi_after_write();
}

boolean online_waiting = false;
boolean online = false;
long when_online = 0;
boolean flash_detected = false;
uint32_t page_buf_size = 256;
uint8_t page_buf[256];

void loop_serial_forwarder() {
  if (!online) {
    online = true;
    // Serial.println("Serial port mode");
  }

  // int debug = Serial.available();

  start_spi(7);  // Select fast serial port

  // First byte is a status byte
  uint8_t my_status =
    // bit 1 = 1 if we have a byte to send
    (Serial.available() ? 0x02 : 0x00)
    // bit 0 = 1 if we have buffer space
    | (Serial.availableForWrite() ? 0x01 : 0x00);

  uint8_t fpga_status = fpga_spi_transfer(my_status);
  // bit 0 of fpga_status = 1 if the fpga has buffer space
  // bit 1 of fpga_status = 1 if the fpga has a byte to send

  uint8_t my_data = 0;
  if ((fpga_status & 0x01) && (my_status & 0x02)) {
    // If the FPGA told us it has buffer space,
    // and we told it that we have a byte to send,
    // then send a byte.
    my_data = (uint8_t)Serial.read();
  }

  uint8_t fpga_data = fpga_spi_transfer(my_data);
  if ((fpga_status & 0x02) && (my_status & 0x01)) {
    // If the FPGA told us it has a byte to send,
    // and we told it we have buffer space, then
    // we just received a byte.
    // Serial.print(fpga_data, HEX); Serial.print(" ");
    Serial.write(fpga_data);
  }

  // Close transfer
  end_spi();

  // if (debug) {
  //   Serial.print("my status ");
  //   Serial.print(my_status, HEX);
  //   Serial.print(" fpga status ");
  //   Serial.print(fpga_status, HEX);
  //   Serial.print(" fpga data ");
  //   Serial.println(fpga_data, HEX);
  //   delay(500);
  // }
}

void loop_command_interface() {
  if (!online) {
    // New connection
    online = true;

    Serial.println(Serial.baud());

    start_spi(5);
    Serial.print("FPGA: ");
    Serial.print(fpga_spi_transfer(0), HEX);  // Expect 55
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi_transfer(0), HEX);
    Serial.print(" ");
    Serial.println(fpga_spi_transfer(0), HEX);
    end_spi();

    Serial.println("Lock passthrough");
    enter_passthrough();

    Serial.print("Flash: ");
    flash_start_spi(0x90);  // read manufacturer / device ID
    flash_send_24bit_addr(0);
    Serial.print(" Winbond: ");
    uint8_t manufacturer = fpga_spi_transfer(0);
    Serial.print(manufacturer, HEX);  // Expect EF (Winbond)
    Serial.print(" W25Q128JV: ");
    uint8_t device_id = fpga_spi_transfer(0);
    Serial.println(device_id, HEX);  // Expect 17 (W25Q128JV)
    end_spi();

    if (manufacturer != 0xef || device_id != 0x17) {
      Serial.println("Flash not detected; aborting");
    } else {
      flash_detected = true;

      Serial.print("Read status 1: ");  // default 0
      Serial.println(read_status1(), HEX);

      Serial.print("Read status 2: ");  // default 0; will be 2 when QE is set
      Serial.println(read_status2(), HEX);

      Serial.print("Read status 3: ");  // default 0x60 (25% drive strength)
      flash_start_spi(0x15);
      Serial.println(fpga_spi_transfer(0), HEX);
      end_spi();

      if (!(read_status2() & STATUS2_QE)) {
        Serial.print("Write NV quad enable bit: ");  // write 0x02 to status 2
        flash_write_enable();
        flash_start_spi(0x31);  // write status 2
        fpga_spi_transfer(STATUS2_QE);
        flash_end_spi_after_write();
        Serial.println("done");
      }
    }

    Serial.println("Unlock passthrough");
    exit_passthrough();
    Serial.println();

  }

  if (Serial.available()) {
    switch (Serial.read()) {
      case '\n': {
        Serial.println("OK");
        break;
      }

      case 'x': {
        // Reset
        online = 0;
        break;
      }

      case 'z': {
        // Reset flash
        start_spi(6);
        fpga_spi_transfer(0);
        end_spi();
        Serial.println("06 00 sent -- FPGA should reset flash now");
        break;
      }

      case 'r': {
        // Read some data.  03h instruction is good up to 50 MHz, so we can use that here.
        enter_passthrough();
        Serial.println("Reading data:");
        flash_start_spi(0x03);  // Read data
        flash_send_24bit_addr(0);
        uint32_t addr;
        uint32_t checksum = 0;
        for (addr = 0; addr < 65536; ++addr) {
          if (!Serial.dtr()) break;
          uint8_t b = fpga_spi_transfer(0);
          if (addr < 512) { Serial.print(" "); Serial.print(b, HEX); }
          checksum += b;
        }
        Serial.println();
        end_spi();
        Serial.print(addr);
        Serial.print(" bytes read; checksum ");
        Serial.println(checksum, HEX);
        exit_passthrough();
        break;
      }

      case 'R': {
        // Read 64kB with binary output
        enter_passthrough();
        Serial.print("DATA:");
        uint32_t checksum = 0;
        uint32_t addr;
        uint32_t blocksize = 256;

        for (uint32_t sector = 0; sector < 65536L; sector += page_buf_size) {
          flash_start_spi(0x03);  // Read data
          flash_send_24bit_addr(sector);
          for (int offset = 0; offset < page_buf_size; ++offset) {
            page_buf[offset] = fpga_spi_transfer(0);
          }
          end_spi();
          if (!Serial.dtr()) break;
          for (int offset = 0; offset < page_buf_size; ++offset) {
            // Serial.write(page_buf[offset]);
            checksum += page_buf[offset];
          }
          // TODO speed up serial write by writing entire page_buf at once;
          // otherwise this sends one byte per usb transaction.  USB code
          // will automatically split into 63-byte packets, so ideal
          // page_buf_size is probably 252.  However the following results in
          // bad data being read on the host side:
          Serial.write(page_buf, page_buf_size);
        }
        Serial.println();
        Serial.print(addr);
        Serial.print(" bytes read; checksum ");
        Serial.println(checksum, HEX);
        exit_passthrough();
        break;
      }

      case 'e': {
        break;  // Easy to accidentally mess up the first ROM with this
        // Erase first sector
        enter_passthrough();
        Serial.println("Erasing first sector");
        erase_sector(0);
        Serial.println("done");
        exit_passthrough();
        break;
      }

      case 'p': {
        break;  // Easy to accidentally mess up the first ROM with this
        Serial.println("Programming something");
        enter_passthrough();
        flash_write_enable();
        flash_start_spi(0x02);  // Page program
        flash_send_24bit_addr(0);
        // program 256 bytes
        for (int a = 0; a < 256; ++a) {
          fpga_spi_transfer((uint8_t)a);
        }
        flash_end_spi_after_write();
        Serial.println("Programmed 256 bytes at 0");
        exit_passthrough();
        break;
      }

      case 'P': {
        Serial.println("Program 64kB from serial port");
        enter_passthrough();
        for (uint32_t sector = 0L; sector < 65536L; sector += 4096L) {
          if (!Serial.dtr()) goto programming_error;
          Serial.print("Erase at ");
          Serial.println(sector, HEX);
          erase_sector(sector);
        }
        for (uint32_t sector = 0L; sector < 65536L; sector += 4096L) {
          for (uint32_t addr = sector; addr < sector + 4096L; addr += 256L) {
            if (!Serial.dtr()) goto programming_error;

            Serial.println("SEND:");
            Serial.print(addr, HEX);
            Serial.print("+");
            Serial.println(256, HEX);
            uint32_t page_checksum = 0;
            for (int a = 0; a < 256; ++a) {
              while (!Serial.available()) {
                if (!Serial.dtr()) goto programming_error;
              }
              page_buf[a] = Serial.read();
              page_checksum += (uint32_t)page_buf[a];
            }
            Serial.print("Checksum ");
            Serial.println(page_checksum, HEX);

            Serial.print("Program page at ");
            Serial.println(addr, HEX);

            flash_write_enable();

            flash_start_spi(0x02);  // Page program
            flash_send_24bit_addr(addr);
            // program 256 bytes
            for (int a = 0; a < 256; ++a) {
              fpga_spi_transfer(page_buf[a]);
            }
            flash_end_spi_after_write();

            Serial.print("Programmed 256 bytes at ");
            Serial.println(addr);

            // Verify
            flash_start_spi(0x03);  // Read data
            flash_send_24bit_addr(addr);
            boolean mismatch = false;
            for (int a = 0; a < 256; ++a) {
              uint8_t b = fpga_spi_transfer(0);
              if (b != page_buf[a]) {
                Serial.print("Mismatch at ");
                Serial.println(addr + a);
                mismatch = true;
              }
            }
            end_spi();
            if (mismatch) {
              Serial.println("ERROR - mismatch");
              goto programming_finished;
            }
          }
        }
        goto programming_finished;
        programming_error:
        Serial.println("ERROR - lost serial comms during programming");
        programming_finished:
        Serial.println("Finished programming");
        Serial.println("OK");
        exit_passthrough();
      }
    }
  }
}

void loop() {
  // Reset everything if we have no serial connection
  int dtr = Serial.dtr();
  if (!dtr) {
    online = false;
    online_waiting = false;
    return;
  }

  // Just went online; delay a tiny bit to allow remote to set baud
  if (!online && !online_waiting) {
    online_waiting = true;
    when_online = millis();
  }

  // Exit wait state if it's been long enough
  if (online_waiting && (millis() - when_online) > 100) {
    online_waiting = false;
  }

  // Online now -- handle input
  if (!online_waiting) {
    int baud = Serial.baud();
    if (baud == 115200) {
      loop_serial_forwarder();
    } else {
      loop_command_interface();
    }
  }
}
