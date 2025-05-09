
`timescale 1ns/1ps

module tb_arbiter_puf();

parameter C_BITS = 4;
parameter R_BITS = 4;

parameter [2*4*C_BITS*R_BITS-1:0] DELAY = 128'hA3F50D7C_1A2B3C4D_55667788_99AABBCC;

reg               reset;
reg               enable;
reg  [C_BITS-1:0] challenge;
wire [R_BITS-1:0] resp;

integer i;

// Instantiate DUT
arbiter_puf #(
  .C_BITS(C_BITS),
  .R_BITS(R_BITS),
  .DELAY(DELAY)
) DUT_A (
  .reset(reset),
  .enable(enable),
  .challenge(challenge),
  .resp(resp)
);


initial begin
  $dumpfile("waveform.vcd");         
  $dumpvars(0, tb_arbiter_puf);      
end

// Query the PUF with a challenge input, display the response output.
task gen_crp;
input [C_BITS-1:0] challenge_in;
begin
  reset = 1'b0;
  enable = 1'b0;
  challenge = challenge_in;

  #10
  reset = 1'b1;
  #10
  reset = 1'b0;
  #10
  enable = 1'b1;

  #(16*C_BITS)

  $display("Challenge: %04b, Response: %b", challenge, resp[0]);

  enable = 1'b0;
end
endtask

initial begin
  gen_crp(0);
  gen_crp(1);
  gen_crp(2);
  gen_crp(3);
  gen_crp(4);
  gen_crp(5);
  gen_crp(6);
  gen_crp(7);
  gen_crp(8);
  gen_crp(9);
  gen_crp(10);
  gen_crp(11);
  gen_crp(12);
  gen_crp(13);
  gen_crp(14);
  gen_crp(15);

  $stop;
end

endmodule


`timescale 1ns/1ps
module arbiter_puf #(
  parameter C_BITS = 4, // Challenge Bits
  parameter R_BITS = 4, // Response Bits
  parameter [2*4*C_BITS*R_BITS-1:0] DELAY = 4'd12 // Random Delay Values
) (
  input               reset,     // Active-high reset to set all registers to 0
  input               enable,    // Enable the PUF circuit
  input  [C_BITS-1:0] challenge, // The PUF challenge input
  output [R_BITS-1:0] resp       // The PUF response output
);

// Internal signals
  wire [C_BITS:0] path0, path1;

  // Initial delays in the circuit
  assign path0[0] = enable;
  assign path1[0] = enable;

  // Series of multiplexers simulating delay paths using mux module, random delay values selected
  genvar i;
  generate
    for (i = 0; i < C_BITS; i = i + 1) begin : delay_chain
      wire delay0, delay1;
      mux #(.DELAY(DELAY[4*i +: 4])) mux_inst0 (
        .a(path1[i]),
        .b(path0[i]),
        .sel(challenge[i]),
        .out(delay0)
      );

      mux #(.DELAY(DELAY[4*C_BITS + 4*i +: 4])) mux_inst1 (
        .a(path0[i]),
        .b(path1[i]),
        .sel(challenge[i]),
        .out(delay1)
      );

      assign path0[i+1] = delay0;
      assign path1[i+1] = delay1;
    end
  endgenerate

  // Arbiter (D Flip-Flop): path0 goes to D input, path1 to CLK
  reg [R_BITS-1:0] response_reg;
  always @(posedge path1[C_BITS] or posedge reset) begin
    if (reset)
      response_reg <= 1'b0;
    else
      response_reg <= path0[C_BITS];
  end

  assign resp = response_reg;


endmodule

module mux #(
  parameter [3:0] DELAY = 10
) (
  input a,
  input b,
  input sel,

  output out
);

wire mux_a;
wire mux_b;

assign out = sel ? mux_a : mux_b;

process_delay_model #(
  .DELAY(DELAY[1:0])
) PDM_A(
  .wire_in(a),
  .wire_out(mux_a)
);

process_delay_model #(
  .DELAY(DELAY[3:2])
) PDM_B(
  .wire_in(b),
  .wire_out(mux_b)
);

endmodule


module process_delay_model #(
  parameter DELAY = 10
) (
  input wire_in,
  output wire_out
);

assign #(DELAY) wire_out = wire_in;

endmodule
