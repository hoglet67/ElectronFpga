module expansion_rom (
    input            clk,
    input [14:0]     addr,
    input            we,
    input [7:0]      data_in,
    output reg [7:0] data_out
);

   reg [7:0]         rom[0:24575];
   
   always @(posedge clk)
     begin
        if (we) begin
           rom[addr] <= data_in;           
        end
        data_out <= rom[addr];  
     end
  
   initial $readmemh("expansion_rom_mmfs_jafa.dat", rom);

endmodule
