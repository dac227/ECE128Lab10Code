`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2026 11:17:21 AM
// Design Name: 
// Module Name: top1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Multiplier_top(input clk, reset, input [2:0] addr1_ROM, addr2_ROM, addr_RAM, output [7:0] result, 
                        output wire [6:0] seg, output wire [3:0] an);
 
    // Control signals from CU
    wire w_rf, DA, SA, SB, w_ram;
    wire [2:0] rom_addr;
    wire [2:0] st_out; 
    
    // Data buses
    wire [3:0] rom_data;     // Output from ROM, goes to RF Data in (D)
    wire [3:0] A_bus, B_bus; // Outputs from RF, go to Multiplier
    wire [7:0] mult_out;     // Output from Multiplier, goes to RAM Write Data

    
    cu uut0 (
        .clk(clk),
        .reset(reset),
        .adr1(addr1_ROM),
        .adr2(addr2_ROM),
        .w_rf(w_rf),
        .adr(rom_addr),
        .DA(DA),
        .SA(SA),
        .SB(SB),
        .st_out(st_out),
        .w_ram(w_ram)
    );

  
    ROM uut1 (
        .addr(rom_addr),
        .data(rom_data) 
    );

    // Register File
    RF uut2 (
        .A(A_bus),
        .B(B_bus),
        .SA(SA),
        .SB(SB),
        .D(rom_data),
        .DA(DA),
        .W(w_rf),
        .rst(reset),
        .clk(clk)
    );

    // Combinational Multiplier
    comb_mult uut3 (
        .a(A_bus),
        .b(B_bus),
        .p(mult_out)
    );

    // RAM
    RAM uut4 (
        .i_clk(clk),
        .i_rst(reset),
        .i_addr(addr_RAM),          // Externally provided RAM address
        .i_write_data(mult_out),    // Data from multiplier
        .i_write_en(w_ram),         // Write enable from CU
        .o_read_data(result)        // Output fed directly to the top level 'result'
    );


    //Section for displaying to seven segment
    
    wire busy;
    wire ready;
    wire [7:0] raw_product;
    wire [15:0] convertedValue;
    wire [1:0]  smallCounterVal;
    wire [3:0]  muxOutput;
    wire [11:0] bcdInput;
    
    wire rst;
    wire rst_n;
    
    wire bcd_en = (st_out == 3'd5);
    assign rst = reset;
    assign rst_n = ~rst;
    
    reg [16:0] refresh_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) refresh_counter <= 17'd0;
        else     refresh_counter <= refresh_counter + 1'b1;
    end
    
    wire refresh_clk = refresh_counter[16];
    
    assign bcdInput = {4'b0000, result};

    bdc12to16bit converter (
        .clk   (clk),
        .rst   (rst),
        .en    (bcd_en),
        .binary(bcdInput),
        .bcd   (convertedValue),
        .rdy   (ready)
    );
    
    smallCounter fastCounter (
        .clk  (refresh_clk),
        .rst_n(rst_n),
        .q    (smallCounterVal)
    );
    
    decoder2to4 dec24 (
        .in (smallCounterVal),
        .out(an)
    );


    mux4to1 mux (
        .bdcInput(convertedValue),
        .decoderInput(an),
        .anodeOutput (muxOutput)
    );


    bcd_7seg_decoder decoder7seg (
        .bcd(muxOutput),
        .seg(seg)
    );

endmodule


    

module RAM(i_clk, i_rst,  i_addr, i_write_data,i_write_en, o_read_data);

parameter DATA_W = 8;
parameter SIZE = 8;
parameter ADDR_W = 3;

input i_clk, i_rst, i_write_en;
input [ADDR_W-1:0] i_addr;
input [DATA_W-1:0] i_write_data;
output reg [DATA_W-1:0] o_read_data;

reg [DATA_W-1:0] mem[0:SIZE-1];// 8 words, each has 4 bits

integer i;

always @(posedge i_clk) begin
	if(i_rst) begin
		for (i=0; i<SIZE;i=i+1) begin
			mem[i] <= 0;
		end
	end
	
	else begin
	if(i_write_en)
	  mem[i_addr] <= i_write_data;
	  else
	  o_read_data<=mem[i_addr];
		end
	end
endmodule	


module RF(A, B, SA, SB, D, DA, W, rst, clk);
	output [3:0]A; // A bus
	output [3:0]B; // B bus
	input SA; // Select A - A Address
	input SB; // Select B - B Address
	input [3:0]D; // Data input
	input DA; // Data destination address
	input W; // write enable
	input rst; // positive logic asynchronous reset
	input clk;
	
	wire [1:0]load_enable;
	wire [3:0]R00, R01;
	
	
	Decoder1to2 decoder (load_enable, DA, W);
	RegisterNbit reg00 (D,R00,load_enable[0], rst, clk); //D-in, R00-out
	RegisterNbit reg01 (D,R01,load_enable[1], rst, clk);
	Mux2to1Nbit muxA (A,R00, R01, SA);
	Mux2to1Nbit muxB (B,R00, R01,SB); 

endmodule

module RegisterNbit(D, Q,  L, R, clock);
	parameter N = 4; // number of bits
	output reg [N-1:0]Q; // registered output
	input [N-1:0]D; // data input
	input L; // load enable
	input R; // positive logic asynchronous reset
	input clock; // positive edge clock
	
	always @(posedge clock or posedge R) begin
		if(R)
			Q <= 0;
		else if(L)
			Q <= D;
		else
			Q <= Q;
	end
endmodule

module Decoder1to2(m, S, en);
	input S; // select
	input en; // enable (positive logic)
	output [1:0]m; // 32 minterms
	
	assign m[0] = ~S&en;
	assign m[1] = S&en;
	
endmodule

module Mux2to1Nbit(o, i1,i2, s);
   input [3:0] i1,i2;
   input  s;
   output reg  [3:0] o;
 
always @(s or i1 or i2)
begin
   case (s)
      1'b0 : o = i1;
      1'b1 : o = i2;
      default : o = 4'b0;
   endcase
end
endmodule

module ROM (
    input [2:0] addr,
    output [3:0] data
);
    // 8 words, 4 bits wide
    reg [3:0] mem [0:7];

    // Runs once at startup (both simulation and synthesis)
    initial begin
        $readmemh("rom_init.mem", mem);
    end

    // Asynchronous read (matches your current CU timing)
    assign data = mem[addr];

endmodule

module bcd_7seg_decoder(input [3:0] bcd, output reg [6:0] seg);

always @(bcd) begin
    case(bcd)
        4'd0: seg = 7'b1000000;
        4'd1: seg = 7'b1111001;
        4'd2: seg = 7'b0100100;
        4'd3: seg = 7'b0110000;
        4'd4: seg = 7'b0011001;
        4'd5: seg = 7'b0010010;
        4'd6: seg = 7'b0000010;
        4'd7: seg = 7'b1111000;
        4'd8: seg = 7'b0000000;
        4'd9: seg = 7'b0010000;
        default: seg = 7'b1111111;
    endcase
   end
endmodule

module bdc12to16bit(input  wire clk, input  wire rst, input wire en, input  wire [11:0] binary, output reg  [15:0] bcd, output reg rdy);

    // State Encoding
    localparam IDLE  = 3'd0;
    localparam SETUP = 3'd1;
    localparam ADD   = 3'd2;
    localparam SHIFT = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0]  state;
    reg [27:0] bcd_data;     // [27:24]=Thousands, [23:20]=Hundreds, [19:16]=Tens, [15:12]=Ones, [11:0]=Binary
    reg [3:0]  sh_counter;   // Counts up to 12 shifts
    reg [1:0]  add_counter;  // Cycles through 4 BCD digits (0 to 3)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            bcd_data    <= 28'b0;
            sh_counter  <= 4'd0;
            add_counter <= 2'd0;
            rdy         <= 1'b0;
            bcd         <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (en) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    bcd_data    <= {16'b0, binary};
                    sh_counter  <= 4'd0;
                    add_counter <= 2'd0;
                    rdy         <= 1'b0;
                    state       <= ADD;
                end

                ADD: begin
                    // Check each BCD digit sequentially; if > 4, add 3
                    case (add_counter)
                        2'd0: begin
                            if (bcd_data[15:12] > 4)
                                bcd_data[15:12] <= bcd_data[15:12] + 4'd3;
                            add_counter <= add_counter + 1'b1;
                        end
                        2'd1: begin
                            if (bcd_data[19:16] > 4)
                                bcd_data[19:16] <= bcd_data[19:16] + 4'd3;
                            add_counter <= add_counter + 1'b1;
                        end
                        2'd2: begin
                            if (bcd_data[23:20] > 4)
                                bcd_data[23:20] <= bcd_data[23:20] + 4'd3;
                            add_counter <= add_counter + 1'b1;
                        end
                        2'd3: begin
                            if (bcd_data[27:24] > 4)
                                bcd_data[27:24] <= bcd_data[27:24] + 4'd3;
                            add_counter <= 2'd0;
                            state       <= SHIFT;
                        end
                    endcase
                end

                SHIFT: begin
                    bcd_data   <= bcd_data << 1;     // Shift entire register left by 1
                    sh_counter <= sh_counter + 1'b1;

                    if (sh_counter == 4'd11) begin   // 12 shifts complete (0 through 11)
                        state <= DONE;
                    end else begin
                        state <= ADD;
                    end
                end

                DONE: begin
                    rdy   <= 1'b1;
                    bcd   <= bcd_data[27:12];        // Extract final 16-bit BCD result
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule


module t_ff (input  wire clk, input  wire rst_n, wire t, output reg  q);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;
        end else begin
            if (t)
                q <= ~q;
            else
                q <= q;
        end
    end

endmodule

module smallCounter (input  wire clk, input  wire rst_n, output wire [1:0] q);

    wire [1:0] t;

    // Toggle logic equations
    assign t[0]  = 1'b1;
    assign t[1]  = q[0];
    
    t_ff ff0 (.clk(clk), .rst_n(rst_n), .t(t[0]), .q(q[0]));
    t_ff ff1 (.clk(clk), .rst_n(rst_n), .t(t[1]), .q(q[1]));

endmodule


module decoder2to4(input [1:0] in, output reg [3:0] out);

    always @(*) begin
        case(in)
            2'b00: out = 4'b1110;
            2'b01: out = 4'b1101;
            2'b10: out = 4'b1011;
            2'b11: out = 4'b0111;
            default: out = 4'b1110;
        endcase
    end
endmodule

module mux4to1(input [15:0] bdcInput, [3:0] decoderInput, output reg [3:0] anodeOutput);

    always @(*) begin
        case(decoderInput)
            4'b1110: anodeOutput = bdcInput[3:0];
            4'b1101: anodeOutput = bdcInput[7:4];
            4'b1011: anodeOutput = bdcInput [11:8];
            4'b0111: anodeOutput = bdcInput [15:12];
        endcase
    end
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2026 11:23:33 AM
// Design Name: 
// Module Name: controlUnit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module cu ( 
  input clk, reset,
  input [2:0] adr1,
  input [2:0] adr2,
  output reg w_rf,
  output reg [2:0] adr,
  output reg DA, SA, SB,
  output reg [2:0] st_out,
  output reg w_ram // Fixed: Was [2:0], changed to 1-bit to match RAM i_write_en
);

  parameter S0_idle = 0, S1_send_adr1 = 1, S2_send_adr2 = 2, S3_multiply = 3, S4_write_ram = 4, S5_read_ram = 5;
  reg [2:0] PS, NS;

  // Sequential block: State updates
  always @(posedge clk or posedge reset) begin
      if(reset)
          PS <= S0_idle;   
      else    
          PS <= NS;
  end  

  // Combinational block: Next state and output logic
  always @(*) begin 
      // Default assignments to prevent inferred latches
      NS = PS;
      w_rf = 1'b0;
      w_ram = 1'b0;
      DA = 1'b0;
      SA = 1'b0;
      SB = 1'b0;
      adr = 3'b000;
      st_out = PS;

      case(PS)
          S0_idle: begin
              NS = S1_send_adr1;
              w_rf = 1'b0;
              w_ram = 1'b0;
              st_out = S0_idle; 
          end
          
          S1_send_adr1: begin	
              w_rf = 1'b1;      // Enable Write to RF
              adr = adr1;       // Send first address to ROM
              DA = 1'b0;        // Set RF destination to R00
              SA = 1'b0;
              SB = 1'b0;
              st_out = S1_send_adr1; 
              NS = S2_send_adr2; 
          end
          
          S2_send_adr2: begin
              w_rf = 1'b1;      // Enable Write to RF
              adr = adr2;       // Send second address to ROM
              DA = 1'b1;        // Set RF destination to R01
              SA = 1'b0;        // Point Mux A to R00
              SB = 1'b1;        // Point Mux B to R01
              st_out = S2_send_adr2; 
              NS = S3_multiply; 
          end
      
          S3_multiply: begin
              // RF writes on the S2->S3 clock edge. 
              // Wait one cycle for combinational multiplier to settle.
              w_ram = 1'b0;     
              SA = 1'b0;        // Keep feeding R00 to A
              SB = 1'b1;        // Keep feeding R01 to B
              st_out = S3_multiply; 
              NS = S4_write_ram; 	
          end

          S4_write_ram: begin
              w_ram = 1'b1;     // Enable RAM write to store multiplier output
              SA = 1'b0;        // Maintain multiplier inputs
              SB = 1'b1;
              st_out = S4_write_ram; 
              NS = S5_read_ram; 	
          end
          
          S5_read_ram: begin
              w_ram = 1'b0;     // Turn off RAM write
              st_out = S5_read_ram; 
              
              if(!reset) begin
                  NS = S5_read_ram; 	
              end else begin
                  NS = S0_idle;
              end
          end
      endcase
  end
endmodule



