module rptr_empty #(parameter ADDRSIZE = 4, 
						  parameter WDATASIZE = 8, 
						  parameter RDATASIZE = 32, 
						  parameter AE_level = 4)(
    input rclk, rrst_n,rinc,
    input [ADDRSIZE:0] rq2_wptr,    
    output reg rempty, almost_empty,
    output [ADDRSIZE-1:0] raddr,
    output reg [$clog2((1<<ADDRSIZE)/(RDATASIZE/WDATASIZE)):0] rptr
    );

    // FIFO depth and read pointer configuration
    localparam DEPTH = 1<<ADDRSIZE;
    localparam RATIO = RDATASIZE/WDATASIZE;
    localparam NUM_GROUPS = DEPTH/RATIO;
    localparam RADDRSIZE = $clog2(NUM_GROUPS);
    localparam RSHIFT = $clog2(RATIO);
    
    reg  [RADDRSIZE:0] rbin;
    wire [RADDRSIZE:0] rgraynext, rbinnext;
    wire [ADDRSIZE:0] rq2_wptr_bin;
    wire [ADDRSIZE:0] rbinnext_full;

    // Update binary and Gray-coded read pointers
    always @(posedge rclk or negedge rrst_n)
        begin
            if(!rrst_n) begin
                rbin <= 0;
                rptr <= 0;
              end
            else begin
                rbin <= rbinnext;
                rptr <= rgraynext;
              end    
        end

    // Generate memory read address and next pointer values
    assign raddr = {rbin[RADDRSIZE-1:0],{RSHIFT{1'b0}}};  
    assign rbinnext = rbin + (rinc & ~rempty);
    assign rgraynext = (rbinnext>>1)^rbinnext;
    
    gray2bin #(ADDRSIZE) gray2bin_1(rq2_wptr , rq2_wptr_bin); // Convert synchronized Gray-coded write pointer to binary
    
    assign rbinnext_full = {rbinnext, {RSHIFT{1'b0}}};

    // Generate empty and almost-empty flags
    always @(posedge rclk or negedge rrst_n)
        begin
            if(!rrst_n) begin
                rempty <= 1'b1;
                almost_empty <= 1'b1;
              end  
            else begin
                rempty <= (rq2_wptr_bin - rbinnext_full) < RATIO;  
                almost_empty <= (rq2_wptr_bin - rbinnext_full <= AE_level);
              end    
        end  
        
endmodule
