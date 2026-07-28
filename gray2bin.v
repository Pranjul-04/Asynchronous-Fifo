module gray2bin #(parameter ADDRSIZE = 4)(
    input [ADDRSIZE:0] gray,
    output reg [ADDRSIZE:0] bin
    );
    
    integer i; // Loop variable for Gray-to-binary conversion

    // Combinational Gray to binary converter
    always @(*) begin
      bin[ADDRSIZE] = gray[ADDRSIZE]; // MSB remains unchanged

        // Each binary bit is obtained by XORing
        // the previous binary bit with the Gray bit
        for(i=ADDRSIZE-1 ; i>=0 ; i=i-1) begin
            bin[i] = bin[i+1]^gray[i];  
        end
    end
endmodule
