/**
 * Firmware for the ATSAMD11C14A chip on board the Ultimate Electron Upgrade board.
 *
 * This chip will probably not be on later versions, once the FPGA's USB port is
 * working.  Right now it provides a convenient USB debug interface, and access to
 * the flash.
 */

#include <SPI.h>

// For pinPeripheral(), so we can change PINMUX
#include "wiring_private.h"

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

void setup() {
  Serial.begin(9600);

  pinMode(FPGA_SS_PIN, OUTPUT);
  digitalWrite(FPGA_SS_PIN, HIGH);
  fpga_spi.begin();
  // All three of these need to be on SERCOM_ALT; I think this is automatic here.
  // The following three lines may be unnecessary.
  pinPeripheral(FPGA_MOSI_PIN, PIO_SERCOM);
  pinPeripheral(FPGA_SCK_PIN,  PIO_SERCOM);
  pinPeripheral(FPGA_MISO_PIN, PIO_SERCOM);
  // 1MHz for debugging so I can easily catch it on a logic analyzer
  fpga_spi.beginTransaction(SPISettings(1000000L, MSBFIRST, SPI_MODE0));

  // Right now TXD_PIN switches the SPI port between the flash (low) and FPGA (high)
  pinMode(TXD_PIN, OUTPUT);
  digitalWrite(TXD_PIN, HIGH);
}

void loop() {
  if (Serial.dtr()) {
    digitalWrite(TXD_PIN, HIGH);
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

    digitalWrite(TXD_PIN, LOW);
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
    Serial.print(fpga_spi.transfer(0), HEX);
    Serial.print(" ");
    Serial.println(fpga_spi.transfer(0), HEX);
    digitalWrite(FPGA_SS_PIN, HIGH);

    delay(1000);
  }
}
