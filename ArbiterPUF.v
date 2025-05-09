
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
