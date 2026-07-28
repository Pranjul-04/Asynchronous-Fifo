module wptr_full #(parameter ADDRSIZE = 4, 
						 parameter RATIO = 4, 
						 parameter AF_level = 12)(
    input wclk, wrst_n, winc,
    input  [$clog2((1<<ADDRSIZE)/RATIO):0] wq2_rptr,
    output reg wfull, almost_full,
    output [ADDRSIZE-1:0] waddr,
    output reg [ADDRSIZE:0] wptr
    );

    // FIFO configuration parameters
    localparam DEPTH      = 1 << ADDRSIZE;
    localparam NUM_GROUPS = DEPTH/RATIO;
    localparam RADDRSIZE  = $clog2(NUM_GROUPS);
    localparam RSHIFT     = $clog2(RATIO);

    reg  [ADDRSIZE:0] wbin;
    wire [ADDRSIZE:0] wbinnext, wgraynext;
    wire [RADDRSIZE:0] wq2_rptr_bin;
    wire [ADDRSIZE:0]  wq2_rptr_bin_full;

    // Update binary and Gray-coded write pointers
    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wbin <= 0;
            wptr <= 0;
        end else begin
            wbin <= wbinnext;
            wptr <= wgraynext;
        end
    end

    // Generate write address and next pointer values
    assign waddr     = wbin[ADDRSIZE-1:0];
    assign wbinnext  = wbin + (winc & ~wfull);
    assign wgraynext = (wbinnext>>1) ^ wbinnext;

  gray2bin #(RADDRSIZE) gray2bin_2(wq2_rptr, wq2_rptr_bin); // Convert synchronized read pointer from Gray to binary
    assign wq2_rptr_bin_full = {wq2_rptr_bin, {RSHIFT{1'b0}}};

    // Generate full and almost-full flags
    always @(posedge wclk or negedge wrst_n) begin
        if(!wrst_n) begin
            wfull <= 1'b0;
            almost_full <= 1'b0;
        end else begin
            wfull       <= (wbinnext - wq2_rptr_bin_full) >= DEPTH;
            almost_full <= (wbinnext - wq2_rptr_bin_full) >= AF_level;
        end
    end
endmodule
