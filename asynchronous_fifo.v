module asynchronous_fifo #(
    parameter WDSIZE = 8, 
    parameter RDSIZE = 32, 
    parameter ASIZE = 4, 
    parameter AE_level = 4, 
    parameter AF_level = 12
)(
    input [WDSIZE-1:0] wdata,
    input winc, wclk, wrst_n,
    input rinc, rclk, rrst_n,
    output [RDSIZE-1:0] rdata,
    output wfull,
    output rempty
);
    // Calculate width conversion ratio for asymmetric FIFO
    localparam RATIO = RDSIZE / WDSIZE;
    localparam R_ASIZE = $clog2((1 << ASIZE) / RATIO);
    
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0]   wptr, rq2_wptr; // Write pointer and synchronized read pointer
    
    wire [R_ASIZE:0] rptr, wq2_rptr; // Read pointer and synchronized write pointer

    // Synchronizes read pointer into write clock domain
    sync_r2w #(.ADDRSIZE(R_ASIZE)) sync_r2w(
        .wq2_rptr(wq2_rptr),
        .rptr(rptr),
        .wclk(wclk),
        .wrst_n(wrst_n)
    );

    // Synchronizes write pointer into read clock domain
    sync_w2r #(.ADDRSIZE(ASIZE)) sync_w2r(
        .rq2_wptr(rq2_wptr),
        .wptr(wptr),
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    // FIFO memory storage block                 
    fifo_mem #(
        .ADDRSIZE(ASIZE), 
        .WDATASIZE(WDSIZE), 
        .RDATASIZE(RDSIZE)
    ) fifo_mem(
        .rdata(rdata), 
        .wdata(wdata),
        .waddr(waddr), 
        .raddr(raddr),
        .wclken(winc), 
        .wfull(wfull),
        .wclk(wclk)
    );

    // Read pointer logic and empty flag generation
    rptr_empty #(
        .ADDRSIZE(ASIZE), 
        .WDATASIZE(WDSIZE), 
        .RDATASIZE(RDSIZE), 
        .AE_level(AE_level)
    ) rptr_empty(
        .rempty(rempty),
        .almost_empty(),  
        .raddr(raddr),
        .rptr(rptr), 
        .rq2_wptr(rq2_wptr),
        .rinc(rinc), 
        .rclk(rclk),
        .rrst_n(rrst_n)
    );

    // Write pointer logic and full flag generation
    wptr_full #(
        .ADDRSIZE(ASIZE), 
        .RATIO(RATIO), 
        .AF_level(AF_level)
    ) wptr_full(
        .wfull(wfull), 
        .almost_full(),   
        .waddr(waddr),
        .wptr(wptr), 
        .wq2_rptr(wq2_rptr),
        .winc(winc), 
        .wclk(wclk),
        .wrst_n(wrst_n)
    );

endmodule
