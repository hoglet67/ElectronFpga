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
 * TXD = PA14 sercom2.0
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
  fpga_spi.beginTransaction(SPISettings(1000000L, MSBFIRST, SPI_MODE0));

  // Right now TXD_PIN switches the SPI port between the flash (low) and FPGA (high)
  pinMode(TXD_PIN, OUTPUT);
  digitalWrite(TXD_PIN, HIGH);
  pinMode(RXD_PIN, INPUT);
}

void loop() {
  if (Serial.dtr()) {
    // Select FPGA
    digitalWrite(TXD_PIN, HIGH);
    Serial.print("TXD high; RXD = ");
    Serial.println(digitalRead(RXD_PIN));

    digitalWrite(FPGA_SS_PIN, LOW);
    Serial.print("FPGA: ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.println(fpga_spi.transfer(0), HEX);
    digitalWrite(FPGA_SS_PIN, HIGH);

    // Select flash
    digitalWrite(TXD_PIN, LOW);
    Serial.print("TXD low; RXD = ");
    Serial.println(digitalRead(RXD_PIN));

    digitalWrite(FPGA_SS_PIN, LOW);
    Serial.print("Flash: ");
    Serial.print(fpga_spi.transfer(0x90), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.print(fpga_spi.transfer(0), HEX);  // Expect EF (Winbond)
    Serial.print(" ");
    Serial.println(fpga_spi.transfer(0), HEX);  // Expect 17 (W25Q128JV)
    digitalWrite(FPGA_SS_PIN, HIGH);

    Serial.println();

    delay(1000);
  }
}
