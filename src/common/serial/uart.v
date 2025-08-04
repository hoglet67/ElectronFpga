module uart
  #(parameter CLK_FREQ_HZ = 0)
   (
    input            clk,
    input            clken,
    input            reset,
    input            we,
    input            enable,
    input [1:0]      addr,
    input [7:0]      di,
    output [7:0]     do,
    output           tx,
    input            rx,
    output           tx_int,
    output           rx_int
    );

   function integer clog2;
      input integer  value;
      begin
         value = value-1;
         for (clog2=0; value>0; clog2=clog2+1)
           value = value>>1;
      end
   endfunction

   localparam DIVIDER_SIZE = clog2(CLK_FREQ_HZ / 75);

   reg [DIVIDER_SIZE-1:0] rx_divider;
   reg [DIVIDER_SIZE-1:0] tx_divider;

   reg [7:0]              rx_buffer[0:3];
   wire [7:0]             rx_data;
   wire                   rx_strb;
   wire                   rx_rdy;
   wire                   rx_ful;
   reg [1:0]              rx_wr_ptr;
   reg [1:0]              rx_rd_ptr;
   wire [1:0]             rx_wr_next;
   wire [1:0]             rx_rd_next;

   reg [7:0]              tx_data;
   reg                    tx_strb;
   wire                   tx_emt;
   wire                   tx_rdy;
   wire                   tx_active;

   reg [7:0]              mr1;
   reg [7:0]              mr2;
   reg                    pointer;

   reg                    reset_rx = 1'b0;
   reg                    reset_tx = 1'b0;
   reg                    reset_err = 1'b0;

   always @(posedge clk)
     if (clken) begin
        tx_strb <= 1'b0;
        reset_rx <= 1'b0;
        reset_tx <= 1'b0;
        reset_err <= 1'b0;
        if (enable & we) begin
           case(addr)
             2'b00 :
               // Mode Register (MR1/2)
               begin
                  if (!pointer) begin
                     mr1 <= di;
                     pointer <= 1'b1;
                  end else begin
                     mr2 <= di;
                  end
               end
             2'b01 :
               // Clock Select Register (CSR)
               // TODO: Implement alterate baud rates when ACR[7]=0
               begin
                  case(di[7:4])
                    4'h0 : rx_divider <= (CLK_FREQ_HZ /    75 - 1);
                    4'h1 : rx_divider <= (CLK_FREQ_HZ /   110 - 1);
                    4'h2 : rx_divider <= (CLK_FREQ_HZ * 2 / 269 - 1); // 134.5
                    4'h3 : rx_divider <= (CLK_FREQ_HZ /   150 - 1);
                    4'h4 : rx_divider <= (CLK_FREQ_HZ /   300 - 1);
                    4'h5 : rx_divider <= (CLK_FREQ_HZ /   600 - 1);
                    4'h6 : rx_divider <= (CLK_FREQ_HZ /  1200 - 1);
                    4'h7 : rx_divider <= (CLK_FREQ_HZ /  2000 - 1);
                    4'h8 : rx_divider <= (CLK_FREQ_HZ /  2400 - 1);
                    4'h9 : rx_divider <= (CLK_FREQ_HZ /  4800 - 1);
                    4'hA : rx_divider <= (CLK_FREQ_HZ /  1800 - 1);
                    4'hB : rx_divider <= (CLK_FREQ_HZ /  9600 - 1);
                    4'hC : rx_divider <= (CLK_FREQ_HZ / 19200 - 1);
                    4'hD : rx_divider <= (CLK_FREQ_HZ / 38400 - 1); // TODO: Timer
                    4'hE : rx_divider <= (CLK_FREQ_HZ / 57600 - 1); // TODO: IP4-16x
                    4'hF : rx_divider <= (CLK_FREQ_HZ /115200 - 1); // TODO: IP4-1x
                  endcase
                  case(di[3:0])
                    4'h0 : tx_divider <= (CLK_FREQ_HZ /    75 - 1);
                    4'h1 : tx_divider <= (CLK_FREQ_HZ /   110 - 1);
                    4'h2 : tx_divider <= (CLK_FREQ_HZ * 2 / 269 - 1); // 134.5
                    4'h3 : tx_divider <= (CLK_FREQ_HZ /   150 - 1);
                    4'h4 : tx_divider <= (CLK_FREQ_HZ /   300 - 1);
                    4'h5 : tx_divider <= (CLK_FREQ_HZ /   600 - 1);
                    4'h6 : tx_divider <= (CLK_FREQ_HZ /  1200 - 1);
                    4'h7 : tx_divider <= (CLK_FREQ_HZ /  2000 - 1);
                    4'h8 : tx_divider <= (CLK_FREQ_HZ /  2400 - 1);
                    4'h9 : tx_divider <= (CLK_FREQ_HZ /  4800 - 1);
                    4'hA : tx_divider <= (CLK_FREQ_HZ /  1800 - 1);
                    4'hB : tx_divider <= (CLK_FREQ_HZ /  9600 - 1);
                    4'hC : tx_divider <= (CLK_FREQ_HZ / 19200 - 1);
                    4'hD : tx_divider <= (CLK_FREQ_HZ / 38400 - 1); // TODO: Timer
                    4'hE : tx_divider <= (CLK_FREQ_HZ / 57600 - 1); // TODO: IP4-16x
                    4'hF : tx_divider <= (CLK_FREQ_HZ /115200 - 1); // TODO: IP4-1x
                  endcase
               end
             2'b10 :
               // Command Register (CR)
               begin
                  case (di[6:4])
                    3'b000:
                      // No command
                      begin end
                    3'b001:
                      // Reset MR pointer
                      pointer <= 1'b0;
                    3'b010:
                      // Reset receiver
                      reset_rx <= 1'b1;
                    3'b011:
                      // Reset transmitter
                      reset_tx <= 1'b1;
                    3'b100:
                      // Reset error status
                      reset_err <= 1'b1;
                    3'b101:
                      // Reset break change interrupt - TODO
                      begin end
                    3'b110:
                      // Start break - TODO
                      begin end
                    3'b111:
                      // Stop break - TODO
                      begin end
                  endcase
               end
             2'b11 :
               // Data Register
               begin
                  tx_data <= di;
                  tx_strb <= 1'b1;
               end
           endcase
        end
     end

   // Receive

   uart_rx #(.DIVIDER_SIZE(DIVIDER_SIZE)) uart_rx
     (
      .i_Clock(clk),
      .i_Rx_Serial(rx),
      .i_Divider(rx_divider),
      .o_Rx_DV(rx_strb),
      .o_Rx_Byte(rx_data)
    );


   // Receive Buffer

   assign rx_wr_next = rx_wr_ptr + 1'b1;
   assign rx_rd_next = rx_rd_ptr + 1'b1;
   assign rx_rdy     = (rx_wr_ptr  != rx_rd_ptr);
   assign rx_ful     = (rx_wr_next == rx_rd_ptr);
   always @(posedge clk)
     if (reset | (clken & reset_rx)) begin
         rx_rd_ptr <= 2'b00;
         rx_wr_ptr <= 2'b00;
     end else begin
        // Write
        if (rx_strb & !rx_ful) begin
           rx_buffer[rx_wr_ptr] <= rx_data;
           rx_wr_ptr <= rx_wr_next;
        end
        // Read
        if (clken & enable & !we & addr == 2'b11 & rx_rdy) begin
           rx_rd_ptr <= rx_rd_next;
        end
      end

   // Transmit

   uart_tx #(.DIVIDER_SIZE(DIVIDER_SIZE)) uart_tx
     (
      .i_Clock(clk),
      .i_Tx_DV(tx_strb),
      .i_Tx_Byte(tx_data),
      .i_Divider(tx_divider),
      .o_Tx_Active(tx_active),
      .o_Tx_Serial(tx),
      .o_Tx_Done()
      );

   assign tx_rdy  = !tx_active;
   assign tx_emt  = !tx_active;
   assign tx_int  = tx_rdy;
   assign rx_int  = rx_rdy;

   wire [7:0] status = { 4'b0000, tx_emt, tx_rdy, rx_ful, rx_rdy};


   assign do = (addr == 2'b00 && !pointer) ? mr1 :
               (addr == 2'b00 &&  pointer) ? mr2 :
               (addr == 2'b01)             ? status :
               rx_buffer[rx_rd_ptr];

endmodule
