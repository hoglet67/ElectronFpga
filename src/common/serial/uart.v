module uart
  #(parameter CLKS_PER_BIT = 0)
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

   reg [7:0]         rx_buffer;
   wire [7:0]        rx_data;
   wire              rx_strb;
   reg               rx_rdy;
   reg               rx_ful;

   reg [7:0]         tx_data;
   reg               tx_strb;
   wire              tx_emt;
   wire              tx_rdy;
   wire              tx_active;

   reg [7:0]         mr1;
   reg [7:0]         mr2;
   reg               pointer;

   reg               reset_rx = 1'b0;
   reg               reset_tx = 1'b0;
   reg               reset_err = 1'b0;

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
               // Clock Select Register (CSR) - TODO
               begin
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

   uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx
     (
      .i_Clock(clk),
      .i_Rx_Serial(rx),
      .o_Rx_DV(rx_strb),
      .o_Rx_Byte(rx_data)
    );

   always @(posedge clk)
      if (reset | (clken & reset_rx) | (clken & enable & !we & addr == 2'b11)) begin
         rx_rdy <= 1'b0;
         rx_ful <= 1'b0;
      end else if (rx_strb) begin
         rx_buffer <= rx_data;
         rx_rdy <= 1'b1;
         rx_ful <= 1'b1;
      end

   // Transmit

   uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx
     (
      .i_Clock(clk),
      .i_Tx_DV(tx_strb),
      .i_Tx_Byte(tx_data),
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
               rx_buffer;

endmodule
