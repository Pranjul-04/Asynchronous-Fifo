module sync_w2r #(parameter ADDRSIZE = 4)
    (input rclk,
    input rrst_n,
    input [ADDRSIZE:0] wptr,
    output reg [ADDRSIZE:0] rq2_wptr
    );
    
    reg [ADDRSIZE:0] rq1_wptr; // First-stage synchronizer register

    // Two-stage synchronizer to safely transfer
    // the write pointer into the read clock domain
    always @(posedge rclk or negedge rrst_n)
        begin
            if(rrst_n==0) begin
                rq1_wptr <= 0;
                rq2_wptr <= 0;
              end
            else 
                {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
        end
        
endmodule
