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
    input            rx
    );

   reg [7:0]         rx_buffer;
   wire [7:0]        rx_data;
   wire              rx_strb;
   reg               rx_rdy;
   reg               rx_ful;

   wire [7:0]        tx_data;
   wire              tx_strb;
   wire              tx_emt;
   wire              tx_rdy;
   wire              tx_active;

   // Receive

   uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx
     (
      .i_Clock(clk),
      .i_Rx_Serial(rx),
      .o_Rx_DV(rx_strb),
      .o_Rx_Byte(rx_data)
    );

   always @(posedge clk)
      if (reset | (clken & enable & !we & addr == 2'b11)) begin
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

   assign tx_data = di;
   assign tx_strb = clken & we & enable & addr == 2'b11;
   assign tx_rdy  = !tx_active;
   assign tx_emt  = !tx_active;

   wire [7:0] status = { 4'b0000, tx_emt, tx_rdy, rx_ful, rx_rdy};


   assign do = (addr == 2'b01) ? status : rx_buffer;

endmodule
