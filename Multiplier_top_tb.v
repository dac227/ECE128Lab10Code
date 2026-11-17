`timescale 1ns / 1ps

module tb_Multiplier_top;

    // --- Testbench Signals ---
    reg clk;
    reg reset;
    reg [2:0] addr1_ROM;
    reg [2:0] addr2_ROM;
    reg [2:0] addr_RAM;
    wire [7:0] result;

    // --- Instantiate Unit Under Test (UUT) ---
    Multiplier_top uut (
        .clk(clk),
        .reset(reset),
        .addr1_ROM(addr1_ROM),
        .addr2_ROM(addr2_ROM),
        .addr_RAM(addr_RAM),
        .result(result)
    );

    // --- Clock Generation (10ns period = 100MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Stimulus Process ---
    initial begin
        // Monitor signals in the console
        $monitor("Time=%0t | State=%0d | ROM_Addrs=(%0d, %0d) | RAM_Addr=%0d | Result=%0d", 
                 $time, uut.uut0.PS, addr1_ROM, addr2_ROM, addr_RAM, result);

        // 1. Initialize Inputs and Hold Reset
        reset = 1;
        addr1_ROM = 3'd0;
        addr2_ROM = 3'd0;
        addr_RAM  = 3'd0;
        #20; // Hold reset for 2 clock cycles

        // ------------------------------------------------------------
        // TEST CASE 1: ROM[1] (3) * ROM[2] (4) -> Store in RAM[0]
        // ------------------------------------------------------------
        addr1_ROM = 3'd1;
        addr2_ROM = 3'd2;
        addr_RAM  = 3'd0;
        reset = 0; // Release reset to start FSM

        // Wait 7 clock cycles for FSM to progress: S0 -> S1 -> S2 -> S3 -> S4 -> S5
        // (S4 writes to RAM, S5 reads from RAM on the next posedge)
        #70; 

        // ------------------------------------------------------------
        // TEST CASE 2: ROM[3] (5) * ROM[4] (6) -> Store in RAM[1]
        // ------------------------------------------------------------
        reset = 1; // Pulse reset to return FSM to S0_idle
        #10;
        addr1_ROM = 3'd3;
        addr2_ROM = 3'd4;
        addr_RAM  = 3'd1;
        reset = 0;

        #70;

        // ------------------------------------------------------------
        // TEST CASE 3: ROM[5] (10) * ROM[7] (15) -> Store in RAM[2]
        // ------------------------------------------------------------
        reset = 1;
        #10;
        addr1_ROM = 3'd5;
        addr2_ROM = 3'd7;
        addr_RAM  = 3'd2;
        reset = 0;

        #70;

        // ------------------------------------------------------------
        // VERIFICATION: Read back earlier RAM locations while in S5
        // ------------------------------------------------------------
        addr_RAM = 3'd0; // Should output 12 (3 * 4)
        #15;
        addr_RAM = 3'd1; // Should output 30 (5 * 6)
        #15;
        addr_RAM = 3'd2; // Should output 150 (10 * 15)
        #15;

        $display("Simulation finished.");
        $finish;
    end

endmodule




