`timescale 1 ns / 1 ps

module pipelined_taylor_series_tb();

// Define timesteps that will help proceed through the simulation
localparam CLK_PERIOD = 24; 				//ns
localparam QSTEP = CLK_PERIOD/4;			//a timestep of quarter clock cycle
localparam TIMESTEP = CLK_PERIOD/8;	   //a small timestep 
// Define input & output precision and number of test inputs
localparam WIDTHIN = 16;
localparam WIDTHOUT = 32;
localparam N_INPUTS = 50;
// Initialize the random number to 2, so the first input has an easy to compute output.
localparam SEED = 32'd2;   
// Define scaling factors to convert inputs and outputs from binary to decimal values with specific fixed point format
localparam i_scale_factor = 2.0**-14.0; // Q2.14 output format
localparam o_scale_factor = 2.0**-25.0; // Q7.25 output format
// Define the error margin allowed in the produced results
localparam error_threshold = 0.045; 

reg clk;
reg reset;
reg i_valid;
reg i_ready;
wire o_valid;
wire o_ready;
reg [WIDTHIN-1:0] i_x;
wire [WIDTHOUT-1:0] o_y;

// Generate a 42MHz clock
initial clk = 1'b1;
always #(CLK_PERIOD/2) clk = ~clk;

// Instantiate the circuit
pipelined_taylor_series
dut	// instance name
(
	.clk(clk),
	.reset(reset),
	.i_valid(i_valid),
	.i_ready(i_ready),
	.o_valid(o_valid),
	.o_ready(o_ready),
	.i_x(i_x),
	.o_y(o_y)
);


function real exp_taylor(input real x);
	real a0, a1, a2, a3, a4, a5;
begin
	a0 = 1.0;
	a1 = 1.0;
	a2 = 0.5;
	a3 = 0.16667;
	a4 = 0.04167;
	a5 = 0.00833;
	exp_taylor = a0 + (a1 * x) + (a2 * (x**2)) + (a3 * (x**3)) + (a4 * (x**4)) + (a5 * (x**5));
end
endfunction

function real exp(input real x);
	real base;
begin
	base = 2.71828;
	exp = base ** x;
end
endfunction
function real error(input real x0, input real x1);
begin
	if(x0 - x1 > 0) begin
		error = x0 - x1;
	end else begin
		error = x1 - x0;
	end
end
endfunction

reg [31:0] prod_rand = SEED;
reg [WIDTHIN-1:0] saved_i_x;
reg valid_stall_tested = 0;
integer prod_i;
initial begin
	
	//i_valid starts low
	i_valid = 1'b0;
	
	// Toggle the reset for a cycle
	reset = 1'b1;
	#(CLK_PERIOD);
	reset = 1'b0;
	
	// Generate N_INPUTS random inputs and deliver to circuit
	for (prod_i = 0; prod_i < N_INPUTS; prod_i = prod_i + 1) begin
		
		//start on posedge
		
		//advance quarter cycle
		#(QSTEP);
		//generate an input value
		i_x = prod_rand[WIDTHIN-1:0];
		saved_i_x = i_x;
		prod_rand = $random(prod_rand);
	
		//advance quarter cycle (now on negedge)
		#(QSTEP);
		//nothing to do here
		
		//advance another quarter cycle
		#(QSTEP);
		//check o_ready and set i_valid
		i_valid = 1'b1;
		while(!o_ready) begin
			//if DUT claims to not be ready, then it shouldn't be an issue if we 
			//give it an erroneous value.
			i_x = 13;
			i_valid = 1'b0;
			
			//wait for a clock period before checking o_ready again
			#(CLK_PERIOD);
			//restore the correct value of i_x if we're going to go out of this while loop
			i_x = saved_i_x;
			i_valid = 1'b1;
		end
		
		//test that DUT stalls properly if we don't give it a valid input
		if (prod_i == N_INPUTS / 2 && !valid_stall_tested) begin
			i_valid = 1'b0;
			i_x = 23; // Strange input to make sure it is ignored.
			#(3*CLK_PERIOD);
			
			//DUT may not be ready at this point, so wait until it is
			while(!o_ready) begin
				#(CLK_PERIOD);
			end

			i_x = saved_i_x;
			i_valid = 1'b1;
			valid_stall_tested = 1;
		end
		
		//advance another quarter cycle to next posedge
		#(QSTEP);
	end
end

// Consumer process: Sequential testbench code to receive output
// from the circuit and verify it. Also stops the simulation when
// all outputs are delivered.
reg [31:0] cns_rand = SEED;
reg [WIDTHOUT-1:0] cns_x;
real good_y;
reg fail = 1'b0;
integer cns_i;
integer current_time = 0;
reg ready_stall_tested = 0;
integer fexp, ftest;
real itr;
initial begin
	// downstream consumer device is initially ready to receive data
	i_ready = 1'b1;

	//delay until just before the first posedge
	#(CLK_PERIOD - TIMESTEP);
	current_time = current_time + (CLK_PERIOD - TIMESTEP);
	
	ftest = $fopen("testcase.txt", "w");
	
	// We generate the same numbers as the producer process
	// by using the same random seed sequence
	for (cns_i = 0; cns_i < N_INPUTS; cns_i = cns_i/*cns_i = cns_i + 1*/) begin

		//we are now at the point just before the posedge
		//check o_valid and compare results
		if (o_valid) begin
			// Use our copy of X to calculate the correct Y
			cns_x = cns_rand[WIDTHIN-1:0];
			cns_rand = $random(cns_rand);
			good_y = exp_taylor($itor(cns_x)*i_scale_factor);
			
			// Display and compare the answer to the known good value
			// We print cns_i, not i_x, as cns_i is the input that led to o_y, 
			// not the current input (which may be out of sync in pipelined designs).
			// Check for equality to pass, so that o_y being unknown (X) is a fail.
			if (error(good_y, $itor(o_y)*o_scale_factor) < error_threshold) begin
				$display("at %dns SUCCESS\t X: %9.6f\t Expected Y: %9.6f\t Got Y: %9.6f\t Error: %9.6f\t < %9.6f", current_time, $itor(cns_x)*i_scale_factor, good_y, $itor(o_y)*o_scale_factor, error(good_y, $itor(o_y)*o_scale_factor), error_threshold);
			end
			else begin
				$display("at %dns FAIL\t X: %9.6f\t Expected Y: %9.6f\t Got Y: %9.6f\t Error: %9.6f\t < %9.6f", current_time, $itor(cns_x)*i_scale_factor, good_y, $itor(o_y)*o_scale_factor, error(good_y, $itor(o_y)*o_scale_factor), error_threshold);
				fail = 1'b1;
			end
			$fwrite(ftest, "%f\t%f\n", $itor(cns_x)*i_scale_factor, $itor(o_y)*o_scale_factor);
		
			//increment our loop counter
			cns_i = cns_i + 1;
		end
		
		//advance to posedge
		#(TIMESTEP);
		current_time = current_time + (TIMESTEP);

		//then advance another quarter cycle
		#(QSTEP);
		current_time = current_time + (QSTEP);

		//set i_ready
		i_ready = 1'b1;
		
		//test that DUT stalls properly if receiver isn't ready
		if (cns_i == N_INPUTS / 8 && !ready_stall_tested) begin
			i_ready = 1'b0;
			//wait for 6 clock periods
			#(6*CLK_PERIOD);
			current_time = current_time + (6*CLK_PERIOD);
			//then restore i_ready
			i_ready = 1'b1;
			ready_stall_tested = 1;
		end
		
		//then advance to just before the next posedge
		#(3*QSTEP - TIMESTEP);
		current_time = current_time + (3*QSTEP - TIMESTEP);

	end
	
	$fclose(ftest);
	$display("%s", fail? "SOME TESTS FAILED" : "ALL TESTS PASSED");
	
	fexp = $fopen("exp.txt", "w");
	
	for(itr = 0; itr < 4.0; itr = itr + 0.02) begin
		$fwrite(fexp, "%f\t%f\n", itr, exp(itr));
	end
	
	$fclose(fexp);
	
	$stop(0);
end

endmodule
module pipelined_taylor_series #
(
	parameter WIDTHIN = 16,		// Input format is Q2.14 (2 integer bits + 14 fractional bits = 16 bits)
	parameter WIDTHOUT = 32,	// Intermediate/Output format is Q7.25 (7 integer bits + 25 fractional bits = 32 bits)
	// Taylor coefficients for the first five terms in Q2.14 format
	parameter [WIDTHIN-1:0] A0 = 16'b01_00000000000000, // a0 = 1
	parameter [WIDTHIN-1:0] A1 = 16'b01_00000000000000, // a1 = 1
	parameter [WIDTHIN-1:0] A2 = 16'b00_10000000000000, // a2 = 1/2
	parameter [WIDTHIN-1:0] A3 = 16'b00_00101010101010, // a3 = 1/6
	parameter [WIDTHIN-1:0] A4 = 16'b00_00001010101010, // a4 = 1/24
	parameter [WIDTHIN-1:0] A5 = 16'b00_00000010001000  // a5 = 1/120
)
(
	input clk,
	input reset,	
	
	input i_valid,
	input i_ready,
	output o_valid,
	output o_ready,
	
	input [WIDTHIN-1:0] i_x,
	output [WIDTHOUT-1:0] o_y
);

reg [WIDTHIN-1:0] x;	// Register to hold input X
reg [WIDTHOUT-1:0] y_Q;	// Register to hold output Y
reg valid_Q1;		// Output of register x is valid
reg valid_Q2;		// Output of register y is valid
reg valid_Q3, valid_Q4, valid_Q5, valid_Q6;		//To pipeline the i_valid signal as many pipeline registers 

/*pipeline D flf*/
reg [WIDTHOUT-1:0] pp1_out1_ff;
reg [WIDTHOUT-1:0] pp2_out2_ff;
reg [WIDTHOUT-1:0] pp3_out3_ff;
reg [WIDTHOUT-1:0] pp4_out4_ff;

/*pipeline the x register*/
reg [WIDTHIN-1:0] x1_Q;
reg [WIDTHIN-1:0] x2_Q;
reg [WIDTHIN-1:0] x3_Q;
reg [WIDTHIN-1:0] x4_Q;

// signal for enabling sequential circuit elements
reg enable;

// Signals for computing the y output
wire [WIDTHOUT-1:0] m0_out; // A5 * x
wire [WIDTHOUT-1:0] a0_out; // A5 * x + A4
wire [WIDTHOUT-1:0] m1_out; // (A5 * x + A4) * x
wire [WIDTHOUT-1:0] a1_out; // (A5 * x + A4) * x + A3
wire [WIDTHOUT-1:0] m2_out; // ((A5 * x + A4) * x + A3) * x
wire [WIDTHOUT-1:0] a2_out; // ((A5 * x + A4) * x + A3) * x + A2
wire [WIDTHOUT-1:0] m3_out; // (((A5 * x + A4) * x + A3) * x + A2) * x
wire [WIDTHOUT-1:0] a3_out; // (((A5 * x + A4) * x + A3) * x + A2) * x + A1
wire [WIDTHOUT-1:0] m4_out; // ((((A5 * x + A4) * x + A3) * x + A2) * x + A1) * x
wire [WIDTHOUT-1:0] a4_out; // ((((A5 * x + A4) * x + A3) * x + A2) * x + A1) * x + A0
wire [WIDTHOUT-1:0] y_D;



// compute y value
mult16x16 Mult0 (.i_dataa(A5), 		.i_datab(x), 	.o_res(m0_out));
addr32p16 Addr0 (.i_dataa(m0_out), 	.i_datab(A4), 	.o_res(a0_out));


mult32x16 Mult1 (.i_dataa(pp1_out1_ff), 	.i_datab(x1_Q), 	.o_res(m1_out));
addr32p16 Addr1 (.i_dataa(m1_out), 	.i_datab(A3), 	.o_res(a1_out));


mult32x16 Mult2 (.i_dataa(pp2_out2_ff), 	.i_datab(x2_Q), 	.o_res(m2_out));
addr32p16 Addr2 (.i_dataa(m2_out), 	.i_datab(A2), 	.o_res(a2_out));


mult32x16 Mult3 (.i_dataa(pp3_out3_ff), 	.i_datab(x3_Q), 	.o_res(m3_out));
addr32p16 Addr3 (.i_dataa(m3_out), 	.i_datab(A1), 	.o_res(a3_out));


mult32x16 Mult4 (.i_dataa(pp4_out4_ff), 	.i_datab(x4_Q), 	.o_res(m4_out));
addr32p16 Addr4 (.i_dataa(m4_out), 	.i_datab(A0), 	.o_res(a4_out));

assign y_D = a4_out;

// Combinational logic
always @* begin
	// signal for enable
	enable = i_ready;
end

always @ (posedge clk or posedge reset) begin
	if(reset) begin
	        /*instatiating the pipeline registers to datapath*/
		pp1_out1_ff <= 0;
	        pp2_out2_ff <= 0;
		pp3_out3_ff <= 0;
		pp4_out4_ff <= 0;
	
	end else if (enable) begin
	        /*adding a pipeline after every multiplier-adder pair and storing the adder value*/
		pp1_out1_ff <= a0_out;
		pp2_out2_ff <= a1_out;
		pp3_out3_ff <= a2_out;
		pp4_out4_ff <= a3_out;
	end
end

// Infer the registers
always @ (posedge clk or posedge reset) begin
	if (reset) begin
	        /*instatiating the valid_Q registers and x registers*/
		valid_Q1 <= 1'b0;
		valid_Q2 <= 1'b0;
		valid_Q3 <= 1'b0;
		valid_Q4 <= 1'b0;
		valid_Q5 <= 1'b0;
		valid_Q6 <= 1'b0;
		x <= 0;
		x1_Q <= 0;
		x2_Q <= 0;
		x3_Q <= 0;
		x4_Q <= 0;
		y_Q <= 0;
	end else if (enable) begin
		// propagate the valid value
		valid_Q1 <= i_valid;
		valid_Q2 <= valid_Q1;
		valid_Q3 <= valid_Q2;
		valid_Q4 <= valid_Q3;
		valid_Q5 <= valid_Q4;
		valid_Q6 <= valid_Q5;
		// read in new x value
		x <= i_x;
		x1_Q <= x;
		x2_Q <= x1_Q;
		x3_Q <= x2_Q;
		x4_Q <= x3_Q;
		// output computed y value
		y_Q <= y_D;
		
	end
end

// assign outputs
assign o_y = y_Q;



// ready for inputs as long as receiver is ready for outputs */
assign o_ready = i_ready;
// the output is valid as long as the corresponding input was valid and 
//	the receiver is ready. If the receiver isn't ready, the computed output
//	will still remain on the register outputs and the circuit will resume
//  normal operation with the receiver is ready again (i_ready is high)*/


assign o_valid = valid_Q6 & i_ready;


endmodule

/*******************************************************************************************/

// Multiplier module for the first 16x16 multiplication
module mult16x16 (
	input  [15:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

reg [31:0] result;

always @ (*) begin
	result = i_dataa * i_datab;
end

// The result of Q2.14 x Q2.14 is in the Q4.28 format. Therefore we need to change it
// to the Q7.25 format specified in the assignment by shifting right and padding with zeros.
assign o_res = {3'b000, result[31:3]};

endmodule

/*******************************************************************************************/

// Multiplier module for all the remaining 32x16 multiplications
module mult32x16 (
	input  [31:0] i_dataa,
	input  [15:0] i_datab,
	output [31:0] o_res
);

reg [47:0] result;

always @ (*) begin
	result = i_dataa * i_datab;
end

// The result of Q7.25 x Q2.14 is in the Q9.39 format. Therefore we need to change it
// to the Q7.25 format specified in the assignment by selecting the appropriate bits
// (i.e. dropping the most-significant 2 bits and least-significant 14 bits).
assign o_res = result[45:14];

endmodule

/*******************************************************************************************/

// Adder module for all the 32b+16b addition operations 
module addr32p16 (
	input [31:0] i_dataa,
	input [15:0] i_datab,
	output [31:0] o_res
);

// The 16-bit Q2.14 input needs to be aligned with the 32-bit Q7.25 input by zero padding
assign o_res = i_dataa + {5'b00000, i_datab, 11'b00000000000};

endmodule

/*******************************************************************************************/
