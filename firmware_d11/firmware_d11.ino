/**
 * Firmware for the ATSAMD11C14A chip on board the Ultimate Electron Upgrade board.
 *
 * This chip will probably not be on later versions, once the FPGA's USB port is
 * working.  Right now it provides a convenient USB debug interface, and access to
 * the flash.
 */

void setup() {
  Serial.begin(9600);
}

void loop() {
  if (Serial.dtr()) {
    Serial.print("hello!\n");
    delay(1000);
  }
}
