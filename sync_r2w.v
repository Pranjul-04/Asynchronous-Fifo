module sync_r2w #(parameter ADDRSIZE = 4)
    (input wclk,
    input wrst_n,
    input [ADDRSIZE:0] rptr,
    output reg [ADDRSIZE:0] wq2_rptr
    );
    
    reg [ADDRSIZE:0] wq1_rptr; // First-stage synchronizer register

    // Two-stage synchronizer to safely transfer
    // the read pointer into the write clock domain
    always @(posedge wclk or negedge wrst_n)
        begin
            if(wrst_n==0) begin
                wq1_rptr <= 0;
                wq2_rptr <= 0;
              end
            else 
                {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
        end
        
endmodule
