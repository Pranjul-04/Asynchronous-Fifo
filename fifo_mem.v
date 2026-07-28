module fifo_mem #(parameter ADDRSIZE = 4,
						parameter WDATASIZE = 8,
					   parameter RDATASIZE = 32)(
   input [WDATASIZE-1:0] wdata,
   input [ADDRSIZE-1:0] waddr, raddr,
   input wclken, wfull, wclk,
   output [RDATASIZE-1:0] rdata  
   );

   // Memory configuration parameters
   localparam DEPTH = 1<<ADDRSIZE;
   localparam RATIO = RDATASIZE/WDATASIZE;

   // FIFO memory array and read data register
   reg [WDATASIZE-1:0] mem [0:DEPTH-1];
   reg [RDATASIZE-1:0] rdata_reg; 
   integer i;

   // Combine multiple narrow words into one wide read word
   always @(*)
    begin
      for(i=0; i<RATIO; i=i+1)
          rdata_reg[i*WDATASIZE+:WDATASIZE] = mem[raddr+i];
    end
    
   assign rdata = rdata_reg;

   // Write data into FIFO memory when enabled and not full
   always @(posedge wclk)
    begin
        if (wclken && !wfull) 
            mem[waddr] <= wdata;
    end        

endmodule
