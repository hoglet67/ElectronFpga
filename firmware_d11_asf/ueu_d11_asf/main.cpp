extern "C" {

#include "atmel_start.h"
#include "cdcdf_acm.h"
#include "cdcdf_acm_desc.h"

}

// 64 byte buffers for OUT data from host and IN data queued for host
#define BUFFER_SIZE CONF_USB_CDCD_ACM_DATA_BULKIN_MAXPKSZ

// Data from host (for serial_available() and serial_read())
// This buffer needs to be word-aligned, or USB functions will fail with -USB_ERR_FUNC.
static uint32_t usb_serial_out_buffer_32[BUFFER_SIZE/4];
static uint8_t *usb_serial_out_buffer = (uint8_t *)usb_serial_out_buffer_32;
volatile static uint8_t *usb_serial_out_ptr = usb_serial_out_buffer;  // Read pointer
volatile static uint32_t usb_serial_out_len = 0;  // Bytes available from host

// data from device (from serial_write())
// This buffer needs to be word-aligned, or USB functions will fail with -USB_ERR_FUNC.
static uint32_t usb_serial_in_buffer_32[BUFFER_SIZE/4];
static uint8_t *usb_serial_in_buffer = (uint8_t *)usb_serial_in_buffer_32;
volatile static uint8_t *usb_serial_in_ptr = usb_serial_in_buffer;  // Write pointer
volatile static uint32_t usb_serial_in_len = 0;  // Bytes to send to host
volatile static bool usb_serial_in_flushing = false;

volatile static uint32_t usb_out_packet_count = 0, usb_out_byte_count = 0;

// BULK OUT handler -- called when we've received new data from the host
static bool usb_device_cb_bulk_out(const uint8_t ep, const enum usb_xfer_code rc, const uint32_t count)
{
    // Make sure there's no unread data in the buffer
    ASSERT(!usb_serial_out_len);

    // For serial debugging
    ++usb_out_packet_count;
    usb_out_byte_count += count;

    // Reset read pointer and available byte count
    usb_serial_out_ptr = usb_serial_out_buffer;
    usb_serial_out_len = count;
	
	if (!usb_serial_out_len) {
		// Zero-length packet; request another one straight away
		cdcdf_acm_read((uint8_t *)usb_serial_out_buffer, BUFFER_SIZE);
	}

    return false;  // Success
}

static bool serial_available() {
    return (usb_serial_out_len > 0);
}

static uint8_t serial_read() {
    if (!usb_serial_out_len) return 0;

    uint8_t c = *usb_serial_out_ptr;

    ++usb_serial_out_ptr;
    --usb_serial_out_len;

    if (!usb_serial_out_len) {
        // Start a new read to handle the next OUT transaction.
        cdcdf_acm_read((uint8_t *)usb_serial_out_buffer, BUFFER_SIZE);
    }

    return c;
}

static bool serial_available_for_write() {
    return (!usb_serial_in_flushing && usb_serial_in_len < BUFFER_SIZE-1);
}

static void serial_flush() {
    // One flush at a time, and no point unless there's data to send to the host
    if (usb_serial_in_flushing || !usb_serial_in_len) return;

    usb_serial_in_flushing = true;
    int32_t rc = cdcdf_acm_write(usb_serial_in_buffer, usb_serial_in_len);
    ASSERT(!rc);
}

static void serial_write(uint8_t c) {
    // assert (serial_available_for_write(), "Writing into a full serial buffer");
    while (!serial_available_for_write());

    usb_serial_in_buffer[usb_serial_in_len++] = c;

    if (!(usb_serial_in_len < BUFFER_SIZE-1)) {
        serial_flush();
    }
}

static void serial_write(uint8_t *buf, int size) {
    while (size--) {
        serial_write(*buf++);
    }
}

static void serial_print(const char *s) {
    while (*s) {
        serial_write(*s++);
    }
    serial_flush();
}

static void serial_println() {
    serial_print("\r\n");
}

static void serial_println(const char *s) {
    serial_print(s);
    serial_println();
}

static void serial_print_dec(uint32_t d) {
    uint32_t modulus = 1;
    while (1) {
        uint32_t new_modulus = modulus * 10;
        if (new_modulus < modulus) {
            serial_print("OVERFLOW ");
            break;
        }
        if (d < new_modulus) {
            // stop one step before this one
            break;
        }
        modulus = new_modulus;
    }

    while (1) {
        uint32_t digit = d / modulus;
        serial_write(digit + '0');
        if (modulus == 1) break;
        d %= modulus;
        modulus /= 10;
    }
    serial_flush();
}

#define to_hex(c) ((c) < 10 ? (c) + '0' : (c) - 10 + 'a')

static void serial_print_hex(uint32_t d, int digits = 0) {
    // Start out with user-suggested digit count
    uint32_t shift = digits > 0 ? (digits - 1) * 4 : 0;
    // ... but extend if we're given a bigger input value
    for (; shift < 28; shift += 4) {
        // Figure out the biggest shift we need.
        // e.g. for ABCD, the biggest shift will be 3 * 4 = 12
        if (d < ((uint32_t)1 << (shift + 4))) break;
    }
    uint32_t mask = 0xF << shift;
    // Write out one digit at a time, left to right
    while (1) {
        uint32_t digit = (d & mask) >> shift;
        serial_write(to_hex(digit));
        if (mask == 0xF) break;
        mask >>= 4;
        shift -= 4;
    }
    serial_flush();
}

// BULK IN handler
static bool usb_device_cb_bulk_in(const uint8_t ep, const enum usb_xfer_code rc, const uint32_t count)
{
    // The host just picked up the contents of the buffer; reset read pointers.
    usb_serial_in_len = 0;
    usb_serial_in_flushing = false;
    usb_serial_in_ptr = usb_serial_in_buffer;
    return false;  // Success
}

volatile static uint32_t _serial_baud;
volatile static bool _serial_dtr;

// Line state change callback
static bool usb_device_cb_state_c(usb_cdc_control_signal_t state)
{
    if (state.rs232.DTR) {
        cdcdf_acm_register_callback(CDCDF_ACM_CB_READ, (FUNC_PTR)usb_device_cb_bulk_out);
        cdcdf_acm_register_callback(CDCDF_ACM_CB_WRITE, (FUNC_PTR)usb_device_cb_bulk_in);

        // Kick off initial read to handle the first OUT transaction.
        cdcdf_acm_read(usb_serial_out_buffer, BUFFER_SIZE);
    }

    _serial_dtr = (bool)state.rs232.DTR;

    return false;  // Success
}

// Line coding callback
static bool usb_device_cb_line_coding_c(struct usb_cdc_line_coding *coding)
{
    _serial_baud = coding->dwDTERate;

    return false;  // Success
}

static uint32_t serial_baud() {
    return _serial_baud;
}

static bool serial_dtr() {
    return _serial_dtr;
}

static void spi_set_ss(bool state) {
  gpio_set_pin_level(PA08, state);
  // digitalWrite(FPGA_SS_PIN, state ? HIGH : LOW);
}

static struct spi_xfer _spi_transfer;
static uint8_t spi_tx_byte, spi_rx_byte;

static uint8_t fpga_spi_transfer(uint8_t c) {
    spi_tx_byte = c;
    spi_m_sync_transfer(&SPI_0, &_spi_transfer);
    return spi_rx_byte;
}

volatile static uint32_t _millis = 0;

static uint32_t millis() { return _millis; }

// millisecond timer
extern "C" void SysTick_Handler(void) {
  ++_millis;
}

// Used by main() but further down in the file
void loop();

extern "C" int main(void)
{
    // Initialize everything from Atmel START including USB
    atmel_start_init();

    // Start millisecond timer
    SysTick_Config(48000000L / 1000);  // TODO why is SystemCoreClock set to 1MHz?

    // Set up SPI SS pin
    gpio_set_pin_level(PA08, false);
    gpio_set_pin_direction(PA08, GPIO_DIRECTION_OUT);
    gpio_set_pin_function(PA08, GPIO_PIN_FUNCTION_OFF);

    // Set up SPI port

    // This actually takes a value for the BAUD register, not the actual baud rate.
    // Calculation details in table 24-2 of the SAM D11 datasheet.
    uint32_t baudrate = 8000000L;
    spi_m_sync_set_baudrate(&SPI_0, (SystemCoreClock / (2 * baudrate)) - 1);
    spi_m_sync_set_mode(&SPI_0, SPI_MODE_0);
    spi_m_sync_enable(&SPI_0);
    _spi_transfer.txbuf = &spi_tx_byte;
    _spi_transfer.rxbuf = &spi_rx_byte;
    _spi_transfer.size = 1;

    // Wait for ACM connection, then hang everything off the state change callback
    while (!cdcdf_acm_is_enabled());
    cdcdf_acm_register_callback(CDCDF_ACM_CB_STATE_C, (FUNC_PTR)usb_device_cb_state_c);
    cdcdf_acm_register_callback(CDCDF_ACM_CB_LINE_CODING_C, (FUNC_PTR)usb_device_cb_line_coding_c);

    // TODO verify disconnecting then reconnecting to USB works.  Suspect that
    // it'll require reregistering the callbacks.

    while (1) {
        loop();
        // while (serial_available() && serial_available_for_write()) {
        //     uint8_t c = serial_read();
        //     serial_write('<');
        //     serial_write(c & ~32);
        //     serial_write('>');
        //     serial_flush();
        // }
    }
}


// --------- shared with Arduino code --------


static bool spi_started = false;

static void start_spi(uint8_t cmd) {
  if (spi_started) {
    serial_println("Attempt to start SPI when already started!");
    while (1);
  }
  spi_started = true;

  spi_set_ss(0);

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
    serial_println("Attempt to end SPI when not started!");
    while (1);
  }
  spi_started = false;

  spi_set_ss(1);
}

static void enter_passthrough() {
  start_spi(1);  // config passthrough
  fpga_spi_transfer(0x01);  // passthrough active
  end_spi();
  delay_ms(1);
}

static void exit_passthrough() {
  start_spi(1);  // config passthrough
  fpga_spi_transfer(0x00);  // passthrough off
  end_spi();
  delay_ms(1);
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

bool flash_busy() {
  uint8_t r = read_status1() & STATUS1_BUSY;
  // if (r) serial_println("BUSY!");
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

bool online_waiting = false;
bool online = false;
long when_online = 0;
bool flash_detected = false;
uint32_t page_buf_size = 256;
uint8_t page_buf[256];

void loop_serial_forwarder() {
  if (!online) {
    online = true;
    // serial_println("Serial port mode");
  }

  // int debug = serial_available();

  start_spi(7);  // Select fast serial port

  // First byte is a status byte
  uint8_t my_status =
    // bit 1 = 1 if we have a byte to send
    (serial_available() ? 0x02 : 0x00)
    // bit 0 = 1 if we have buffer space
    | (serial_available_for_write() ? 0x01 : 0x00);

  uint8_t fpga_status = fpga_spi_transfer(my_status);
  // bit 0 of fpga_status = 1 if the fpga has buffer space
  // bit 1 of fpga_status = 1 if the fpga has a byte to send

  uint8_t my_data = 0;
  if ((fpga_status & 0x01) && (my_status & 0x02)) {
    // If the FPGA told us it has buffer space,
    // and we told it that we have a byte to send,
    // then send a byte.
    my_data = (uint8_t)serial_read();
  }

  uint8_t fpga_data = fpga_spi_transfer(my_data);
  if ((fpga_status & 0x02) && (my_status & 0x01)) {
    // If the FPGA told us it has a byte to send,
    // and we told it we have buffer space, then
    // we just received a byte.
    // serial_print_hex(fpga_data); serial_print(" ");
    serial_write(fpga_data);
    serial_flush();
  }

  // Close transfer
  end_spi();

  // if (debug) {
  //   serial_print("my status ");
  //   serial_print_hex(my_status);
  //   serial_print(" fpga status ");
  //   serial_print_hex(fpga_status);
  //   serial_print(" fpga data ");
  //   serial_print_hex(fpga_data); serial_println();
  //   delay(500);
  // }
}

void loop_command_interface() {
  if (!online) {
    // New connection
    online = true;

    serial_print_dec(serial_baud());
    serial_println();

    start_spi(5);
    serial_print("FPGA: ");
    serial_print_hex(fpga_spi_transfer(0));  // Expect 55
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0));
    serial_print(" ");
    serial_print_hex(fpga_spi_transfer(0)); serial_println();
    end_spi();

    serial_println("Lock passthrough");
    enter_passthrough();

    serial_print("Flash: ");
    flash_start_spi(0x90);  // read manufacturer / device ID
    flash_send_24bit_addr(0);
    serial_print(" Winbond: ");
    uint8_t manufacturer = fpga_spi_transfer(0);
    serial_print_hex(manufacturer);  // Expect EF (Winbond)
    serial_print(" W25Q128JV: ");
    uint8_t device_id = fpga_spi_transfer(0);
    serial_print_hex(device_id); serial_println();  // Expect 17 (W25Q128JV)
    end_spi();

    if (manufacturer != 0xef || device_id != 0x17) {
      serial_println("Flash not detected; aborting");
    } else {
      flash_detected = true;

      serial_print("Read status 1: ");  // default 0
      serial_print_hex(read_status1()); serial_println();

      serial_print("Read status 2: ");  // default 0; will be 2 when QE is set
      serial_print_hex(read_status2()); serial_println();

      serial_print("Read status 3: ");  // default 0x60 (25% drive strength)
      flash_start_spi(0x15);
      serial_print_hex(fpga_spi_transfer(0)); serial_println();
      end_spi();

      if (!(read_status2() & STATUS2_QE)) {
        serial_print("Write NV quad enable bit: ");  // write 0x02 to status 2
        flash_write_enable();
        flash_start_spi(0x31);  // write status 2
        fpga_spi_transfer(STATUS2_QE);
        flash_end_spi_after_write();
        serial_println("done");
      }
    }

    serial_println("Unlock passthrough");
    exit_passthrough();
    serial_println();

  }

  if (serial_available()) {
    switch (serial_read()) {
      case '\n': {
        serial_println("OK");
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
        serial_println("06 00 sent -- FPGA should reset flash now");
        break;
      }

      case 'r': {
        // Read some data.  03h instruction is good up to 50 MHz, so we can use that here.
        enter_passthrough();
        serial_println("Reading data:");
        flash_start_spi(0x03);  // Read data
        flash_send_24bit_addr(0);
        uint32_t addr;
        uint32_t checksum = 0;
        for (addr = 0; addr < 65536; ++addr) {
          if (!serial_dtr()) break;
          uint8_t b = fpga_spi_transfer(0);
          if (addr < 512) {
            serial_print(" ");
            serial_print_hex(b);
          }
          checksum += b;
        }
        serial_println();
        end_spi();
        serial_print_hex(addr);
        serial_print(" bytes read; checksum ");
        serial_print_hex(checksum); serial_println();
        exit_passthrough();
        break;
      }

      case 'R': {
        // Read 64kB with binary output
        enter_passthrough();
        serial_print("DATA:");
        uint32_t checksum = 0;
        uint32_t addr = 0;

        for (uint32_t sector = 0; sector < 65536L; sector += page_buf_size) {
          flash_start_spi(0x03);  // Read data
          flash_send_24bit_addr(sector);
          for (uint32_t offset = 0; offset < page_buf_size; ++offset) {
            page_buf[offset] = fpga_spi_transfer(0);
          }
          end_spi();
          if (!serial_dtr()) break;
          for (uint32_t offset = 0; offset < page_buf_size; ++offset) {
            // serial_write(page_buf[offset]);
            checksum += page_buf[offset];
          }
          // TODO speed up serial write by writing entire page_buf at once;
          // otherwise this sends one byte per usb transaction.  USB code
          // will automatically split into 63-byte packets, so ideal
          // page_buf_size is probably 252.  However the following results in
          // bad data being read on the host side:
          serial_write(page_buf, page_buf_size);
        }
        serial_println();
        serial_print_hex(addr);
        serial_print(" bytes read; checksum ");
        serial_print_hex(checksum); serial_println();
        exit_passthrough();
        break;
      }

      case 'e': {
        break;  // Easy to accidentally mess up the first ROM with this
        // Erase first sector
        enter_passthrough();
        serial_println("Erasing first sector");
        erase_sector(0);
        serial_println("done");
        exit_passthrough();
        break;
      }

      case 'p': {
        break;  // Easy to accidentally mess up the first ROM with this
        serial_println("Programming something");
        enter_passthrough();
        flash_write_enable();
        flash_start_spi(0x02);  // Page program
        flash_send_24bit_addr(0);
        // program 256 bytes
        for (int a = 0; a < 256; ++a) {
          fpga_spi_transfer((uint8_t)a);
        }
        flash_end_spi_after_write();
        serial_println("Programmed 256 bytes at 0");
        exit_passthrough();
        break;
      }

      case 'P': {
        serial_println("Program 64kB from serial port");
        enter_passthrough();
        for (uint32_t sector = 0L; sector < 65536L; sector += 4096L) {
          if (!serial_dtr()) goto programming_error;
          serial_print("Erase at ");
          serial_print_hex(sector); serial_println();
          erase_sector(sector);
        }
        for (uint32_t sector = 0L; sector < 65536L; sector += 4096L) {
          for (uint32_t addr = sector; addr < sector + 4096L; addr += 256L) {
            if (!serial_dtr()) goto programming_error;

            serial_println("SEND:");
            serial_print_hex(addr);
            serial_print("+");
            serial_print_hex(256);
            serial_println();
            uint32_t page_checksum = 0;
            for (int a = 0; a < 256; ++a) {
              while (!serial_available()) {
                if (!serial_dtr()) goto programming_error;
              }
              page_buf[a] = serial_read();
              page_checksum += (uint32_t)page_buf[a];
            }
            serial_print("Checksum ");
            serial_print_hex(page_checksum); serial_println();

            serial_print("Program page at ");
            serial_print_hex(addr); serial_println();

            flash_write_enable();

            flash_start_spi(0x02);  // Page program
            flash_send_24bit_addr(addr);
            // program 256 bytes
            for (int a = 0; a < 256; ++a) {
              fpga_spi_transfer(page_buf[a]);
            }
            flash_end_spi_after_write();

            serial_print("Programmed 256 bytes at ");
            serial_print_hex(addr);
            serial_println();

            // Verify
            flash_start_spi(0x03);  // Read data
            flash_send_24bit_addr(addr);
            bool mismatch = false;
            for (int a = 0; a < 256; ++a) {
              uint8_t b = fpga_spi_transfer(0);
              if (b != page_buf[a]) {
                serial_print("Mismatch at ");
                serial_print_hex(addr + a);
                serial_println();
                mismatch = true;
              }
            }
            end_spi();
            if (mismatch) {
              serial_println("ERROR - mismatch");
              goto programming_finished;
            }
          }
        }
        goto programming_finished;
        programming_error:
        serial_println("ERROR - lost serial comms during programming");
        programming_finished:
        serial_println("Finished programming");
        serial_println("OK");
        exit_passthrough();
      }
    }
  }
}

// code to help diagnose behaviour where the host sends a big packet and only part of it gets received.
void loop_serial_debug() {
    uint32_t last_report = millis();  // last time we reported stats to the host
    uint32_t last_rx = millis();  // last time we received a packet
    bool waiting = false;  // are we waiting before requesting a new packet?
    uint32_t wait_delay = 0; // how long to pause before requesting next packet

    // observed behaviour: a python script sending 63-byte packets using
    // pyserial can send as many as it likes, and they all get received. it
    // seems to work up to 127 bytes per packet, but sending 128 results in
    // the python script getting a success, but hanging (presumably not all
    // the data is being received on the other end).  i don't know how much of
    // it is successfully being sent, however.

    // the arduino (mattairtech mt-d11) code seems to handle big packets
    // better, although i've observed this 63-byte thing with the arduino
    // leonardo and the circuit playground (atsamd21) usb stacks.

    // how usb works: the host sends a stream of OUT packets of up to 64 bytes
    // each; the presence of a packet with length < 64 means the transaction
    // is done (which means a zero length packet is required when sending an
    // exact multiple of 64 bytes).

    // the device can respond to a packet with ACK or NAK.  NAK means the
    // device can't process the packet right now, and the host should just
    // keep retrying.  this guy
    // (https://www.eevblog.com/forum/microcontrollers/usb-cdc-_flow-control_/)
    // verified that his machine will happily keep retrying overnight, so we
    // shouldn't find that the usb stack times out after some number of
    // milliseconds.

    // it would be really nice to have a fast usb analyzer or at least
    // something that can decode a .vcd file of a usb trace and see what's
    // really going on...

    while (1) {
        uint32_t now = millis();

        if (usb_serial_out_len) {
            // drop incoming data
            usb_serial_out_len = 0;
            // and prep usb for more after wait_delay ms
            waiting = true;
            last_rx = now;
        }

        if ((now - last_rx > 1000) || (waiting && (now - last_rx) > wait_delay)) {
            cdcdf_acm_read((uint8_t *)usb_serial_out_buffer, BUFFER_SIZE);
            waiting = false;
        }

        if ((now - last_report) > 250) {
            uint32_t bc = usb_out_byte_count, pc = usb_out_packet_count;
            usb_out_byte_count = 0;
            usb_out_packet_count = 0;
            last_report = now;

            serial_print_dec(bc);
            serial_print(" bytes in ");
            serial_print_dec(pc);
            serial_println(" packets;");
        }
    }
}

void loop() {
  // Reset everything if we have no serial connection
  int dtr = serial_dtr();
  if (!dtr) {
    online = false;
    online_waiting = false;
    return;
  }

  // loop_serial_debug(); return;

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
    int baud = serial_baud();
    if (baud == 115200) {
      loop_serial_forwarder();
    } else {
      loop_command_interface();
    }
  }
}
