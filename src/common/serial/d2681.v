module d2681
  #(parameter CLKS_PER_BIT = 0)
  (
   input        clk,
   input        reset,
   input        clken,
   input        enable,
   input        we,
   input [3:0]  addr,
   input [7:0]  di,
   output [7:0] do,
   input [6:0]  ip_n,
   output [7:0] op_n,
   output       txa,
   input        rxa,
   output       txb,
   input        rxb,
   output       intr_n
   );

   wire [7:0]       doa;
   wire [7:0]       dob;
   reg [7:0]        op = 8'h00;
   reg [7:0]        imr = 8'h00;
   reg [15:0]       counter_preset = 8'h00;
   reg [15:0]       counter_value = 8'h00;

   // Note: IP/OP ports are inverted
   wire [6:0]       ip = ~ip_n;
   assign           op_n = ~op;

   uart #(.CLKS_PER_BIT(CLKS_PER_BIT)) uarta
     (
      .clk(clk),
      .clken(clken),
      .reset(reset),
      .we(we),
      .enable(enable & addr[3:2] == 2'b00),
      .addr(addr[1:0]),
      .di(di),
      .do(doa),
      .tx(txa),
      .rx(rxa)
      );

   uart #(.CLKS_PER_BIT(CLKS_PER_BIT)) uartb
     (
      .clk(clk),
      .clken(clken),
      .reset(reset),
      .we(we),
      .enable(enable & addr[3:2] == 2'b10),
      .addr(addr[1:0]),
      .di(di),
      .do(dob),
      .tx(txb),
      .rx(rxb)
      );

   always @(posedge clk) begin
      if (clken) begin
         if (enable & we) begin
            if (addr == 4'h5)
              imr <= di;
            else if (addr == 4'h6)
              counter_preset[15:8] <= di;
            else if (addr == 4'h7)
              counter_preset[7:0] <= di;
            else if (addr == 4'hE)
              op <= op | di;
            else if (addr == 4'hF)
              op <= op & ~di;
         end
      end
   end

   // Counter/Timer

   // TODO: Only counter mode 000 is currently implemented

   reg last_ip2 = 1'b0;
   reg counter_ready_int = 1'b0;
   reg counter_running = 1'b0;

   always @(posedge clk) begin
      last_ip2 <= ip[2];
      if (counter_running && !last_ip2 && ip[2]) begin
         // This should be 0001, but the tracing NMI was happing a couple of cycles early
         if (counter_value == 16'hffff)
           counter_ready_int <= 1'b1;
         counter_value <= counter_value - 1'b1;
      end
      if (clken) begin
         if (enable & !we) begin
            if (addr == 4'hE) begin
               counter_value <= counter_preset;
               counter_running <= 1'b1;
            end else if (addr == 4'hF) begin
               counter_running <= 1'b0;
               counter_ready_int <= 1'b0;
            end
         end
      end
   end

   wire [7:0] isr = { 4'b0000, counter_ready_int, 3'b000};

   assign intr_n = !(|(imr & isr));

   assign do = (addr == 4'h1) || (addr == 4'h3) ? doa                 :
               (addr == 4'h5)                   ? isr                 :
               (addr == 4'h6)                   ? counter_value[15:8] :
               (addr == 4'h7)                   ? counter_value[ 7:0] :
               (addr == 4'h9) || (addr == 4'hb) ? dob                 :
               (addr == 4'hd)                   ? ip                  :
               8'hFF;

endmodule
