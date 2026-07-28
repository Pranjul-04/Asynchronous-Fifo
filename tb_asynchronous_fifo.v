module tb_asynchronous_fifo;

    // FIFO configuration parameters
    parameter WDSIZE   = 8;
    parameter RDSIZE   = 32;
    parameter ASIZE    = 4;
    parameter AE_level = 4;
    parameter AF_level = 12;

    // Derived FIFO parameters
    localparam RATIO   = RDSIZE / WDSIZE;
    localparam DEPTH   = 1 << ASIZE;
    localparam MAX_TEST_BYTES = 2048; 

    reg  wclk=0, wrst_n=0, winc=0;
    reg  rclk=0, rrst_n=0, rinc=0;
    reg  [WDSIZE-1:0] wdata=0;
    wire [RDSIZE-1:0] rdata;
    wire wfull, rempty;

    integer errors = 0;
    integer w_idx = 0; 
    integer r_idx = 0; 
    integer fd, i;
    real w_jitter, r_jitter;

  reg [WDSIZE-1:0] file_mem [0:MAX_TEST_BYTES-1]; // Memory used to store test data


    // Generate write clock with random jitter
    always begin
        w_jitter = ($unsigned($random) % 1000) / 1000.0;
        #(3.0 + w_jitter) wclk = ~wclk; 
    end

    // Generate read clock with random jitter
    always begin
        r_jitter = ($unsigned($random) % 1000) / 1000.0;
        #(5.0 + r_jitter) rclk = ~rclk; 
    end

    // Instantiate asynchronous FIFO
    asynchronous_fifo #(
        .WDSIZE(WDSIZE), .RDSIZE(RDSIZE), .ASIZE(ASIZE), 
        .AE_level(AE_level), .AF_level(AF_level)
    ) dut (
        .wdata(wdata), .winc(winc), .wclk(wclk), .wrst_n(wrst_n),
        .rinc(rinc),   .rclk(rclk), .rrst_n(rrst_n),
        .rdata(rdata), .wfull(wfull), .rempty(rempty)
    );

   // Apply reset to both clock domains
    task reset_fifo;
        begin
            $display("[%0t] Asserting Resets...", $time);
            winc = 0; rinc = 0; wdata = 0;
            wrst_n = 0; rrst_n = 0;
            repeat(5) @(posedge wclk);
            
            @(negedge wclk) wrst_n = 1; 
            @(negedge rclk) rrst_n = 1;
            repeat(3) @(posedge wclk);
            $display("[%0t] Reset Complete.", $time);
        end
    endtask

    // Write a burst of data into the FIFO
    task write_blast(input integer bytes_to_write);
        integer w_cnt; 
        begin
            w_cnt = 0; 
            while (w_cnt < bytes_to_write) begin
                @(negedge wclk);
                if (!wfull) begin
                    wdata = file_mem[w_idx];
                    winc  = 1;
                    w_idx = w_idx + 1;
                    w_cnt = w_cnt + 1;
                end else begin
                    winc = 0; 
                end
            end
            @(negedge wclk) winc = 0; 
        end
    endtask

    // Read FIFO data and verify correctness
    task read_and_check(input integer words_to_read);
        integer r_cnt; 
        reg [RDSIZE-1:0] exp_data;
        begin
            r_cnt = 0;
            while (r_cnt < words_to_read) begin
                @(negedge rclk);
                if (!rempty) begin
                    exp_data = {file_mem[r_idx+3], file_mem[r_idx+2], file_mem[r_idx+1], file_mem[r_idx]};
                    
                    if (rdata !== exp_data) begin
                        $display("[%0t] ERROR! Exp: %08h, Got: %08h", $time, exp_data, rdata);
                        errors = errors + 1;
                    end
                    
                    rinc = 1; 
                    @(negedge rclk); 
                    rinc = 0;
                    r_idx = r_idx + RATIO;
                    r_cnt = r_cnt + 1;
                end else begin
                    rinc = 0;
                end
            end
        end
    endtask

    // Perform random concurrent read/write stress testing
    task random_stutter_stress(input integer target_bytes);
        reg [RDSIZE-1:0] exp_data;
        begin
            $display("[%0t] Starting Random Stutter Stress (Target: %0d bytes)", $time, target_bytes);
            fork
                // Randomized write process
                begin
                    while (w_idx < target_bytes) begin
                        @(negedge wclk);
                        if (!wfull) begin
                            wdata = file_mem[w_idx];
                            winc  = 1;
                            w_idx = w_idx + 1;
                            
                            if ($unsigned($random) % 100 < 20) begin
                                @(negedge wclk) winc = 0;
                                repeat($unsigned($random) % 10) @(negedge wclk);
                            end
                        end else begin
                            winc = 0;
                        end
                    end
                    @(negedge wclk) winc = 0;
                end
                // Randomized read process
                begin
                    while (r_idx < target_bytes) begin
                        @(negedge rclk);
                        if (!rempty) begin
                            exp_data = {file_mem[r_idx+3], file_mem[r_idx+2], file_mem[r_idx+1], file_mem[r_idx]};
                            if (rdata !== exp_data) begin
                                $display("[%0t] ERROR! Exp: %08h, Got: %08h", $time, exp_data, rdata);
                                errors = errors + 1;
                            end
                            rinc = 1; 
                            @(negedge rclk); 
                            rinc = 0;
                            r_idx = r_idx + RATIO;
                                if ($unsigned($random) % 100 < 30) begin
                                repeat($unsigned($random) % 15) @(negedge rclk);
                            end
                        end else begin
                            rinc = 0;
                        end
                    end
                end
            join
        end
    endtask

    // Main test sequence
    initial begin

        // Generate test data file
        fd = $fopen("burst_data.hex", "w");
        for (i = 0; i < MAX_TEST_BYTES; i = i + 1) begin
            $fdisplay(fd, "%02h", (i * 11) & 8'hFF); 
        end
        $fclose(fd);

        // Load test data into memory
        $readmemh("burst_data.hex", file_mem);

        reset_fifo();

        // Sequential write/read verification
        $display("\n Sequential Blast");
        write_blast(DEPTH);       
        
        read_and_check(DEPTH/RATIO);  

        // Simultaneous read and write operation
        $display("\n Controlled Concurrent Stress ");
        fork
            write_blast(256);         
            begin
                #100; 
                read_and_check(64);   
            end
        join

        // Randomized stress test with clock jitter
        $display("\n Randomized Jitter Stress");
        random_stutter_stress(MAX_TEST_BYTES);

        // Display final test results
        repeat(15) @(posedge wclk);
        if (errors == 0 && w_idx == MAX_TEST_BYTES && r_idx == MAX_TEST_BYTES)
            $display("   TEST PASSED! 0 Errors");
        else
            $display("   TEST FAILED! %0d Errors found.", errors);
        $display("   Total Bytes Written: %0d", w_idx);
        $display("   Total Bytes Read:    %0d", r_idx);
        $finish;
    end

    // Prevent simulation from running indefinitely
    initial begin 
        #(5000000); 
        $display("\nERROR: Simulation Timeout."); 
        $finish; 
    end

endmodule
