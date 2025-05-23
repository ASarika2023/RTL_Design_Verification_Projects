`timescale 1ns / 1ps

module tb_top;

parameter Addr_Width = 4;
parameter Data_Width = 8;

reg wclk, wrst_n, rclk, rrst_n;
reg winc, rinc;
reg [Data_Width-1:0] wdata;
wire [Data_Width-1:0] rdata;
wire wfull, rempty;

// Instantiate the top module
top #(Addr_Width, Data_Width) dut (
    .wclk(wclk),
    .wrst_n(wrst_n),
    .rclk(rclk),
    .rrst_n(rrst_n),
    .wdata(wdata),
    .rdata(rdata),
    .winc(winc),
    .rinc(rinc),
    .wfull(wfull),
    .rempty(rempty)
);

// Generate write clock (100 MHz)
initial begin
    wclk = 0;
    forever #5 wclk = ~wclk;
end

// Generate read clock (~71 MHz)
initial begin
    rclk = 0;
    forever #7 rclk = ~rclk;
end

// Simulation sequence
initial begin
    $dumpfile("fifo_test.vcd");
    $dumpvars(0, tb_top);

    wrst_n = 0; rrst_n = 0;
    winc = 0; rinc = 0;
    wdata = 0;

    #20;
    wrst_n = 1; rrst_n = 1;

    $display("\n=== Start Writing ===");
    repeat ((1 << Addr_Width)) begin
        @(posedge wclk);
        if (!wfull) begin
            wdata = wdata + 1;
            winc = 1;
            $display("Time %0t: Writing 0x%0h", $time, wdata);
        end else begin
            $display("Time %0t: FIFO FULL ? cannot write", $time);
        end
    end
    @(posedge wclk);
    winc = 0;

    @(posedge wclk);
    if (wfull)
        $display("Time %0t: Write correctly blocked ? FIFO is full", $time);
    else
        $display("Time %0t: ERROR ? FIFO should be full but isn't", $time);

    // Wait before reading
    #50;

    $display("\n=== Start Reading ===");
    repeat ((1 << Addr_Width)) begin
        @(posedge rclk);
        if (!rempty) begin
            rinc = 1;
            $display("Time %0t: Reading 0x%0h", $time, rdata);
        end else begin
            $display("Time %0t: FIFO EMPTY ? cannot read", $time);
        end
    end
    @(posedge rclk);
    rinc = 0;

    @(posedge rclk);
    if (rempty)
        $display("Time %0t: Read correctly blocked ? FIFO is empty ", $time);
    else
        $display(" Time %0t: ERROR ? FIFO should be empty but isn't", $time);

    #50;
    $display("\n? Simulation complete.");
    $finish;
end

endmodule


module top #(parameter Addr_Width =4,
 	     parameter Data_Width =8)
(input wclk,
input wrst_n,
input rclk,
input rrst_n,
input [Data_Width -1 :0] wdata,
output [Data_Width -1 :0] rdata,
input winc,
input rinc,
output rempty,
output wfull);
wire [Addr_Width :0] rptr, wptr, wq2_rptr, rq2_wptr;
wire [Addr_Width :0] waddr, raddr;

wire wclken = winc && (!wfull);

fifo_mem memory(.w_data(wdata), .w_addr(waddr), .wclk(wclk), .rclk(rclk), .wclken(wclken), .rempty(rempty), .r_data(rdata),.r_addr(raddr));
sync_r2w write_pointer(.wclk(wclk),.wrst_n(wrst_n), .rptr(rptr), .wq2_rptr(wq2_rptr));
sync_w2r read_pointer(.rclk(rclk), .rrst_n(rrst_n), .wptr(wptr), . rq2_wptr(rq2_wptr));
fifo_m1 full(.winc(winc), .wq2_rptr(wq2_rptr), .wclk(wclk), .wrst_n(wrst_n), .wfull(wfull), .waddr(waddr), .wptr(wptr));
fifo_m2 empty(.rinc(rinc), .rclk(rclk), .rq2_wptr(rq2_wptr), .rrst_n(rrst_n), .raddr(raddr), .rptr(rptr), .rempty(rempty));

endmodule

module sync_w2r #(parameter Addr_Width = 4)
(input [Addr_Width : 0] wptr,
input rclk,
input rrst_n,
output [Addr_Width:0] rq2_wptr);
reg [Addr_Width :0] temp1, temp2;

assign rq2_wptr = temp2;
always@(rclk) begin //so we synchronise the wptr to check the empty condition, but we only check it on the rclk?
	if(!rrst_n) begin
		temp1<= 0;
		temp2<=0;
	end
	else begin
		temp1 <= wptr;
		temp2 <= temp1;
	end
	end
endmodule
 

module sync_r2w #(parameter Addr_Width =4)
(input wclk,
input wrst_n,
input [Addr_Width :0] rptr,
output[Addr_Width:0] wq2_rptr);

reg [Addr_Width:0] temp1, temp2;

assign wq2_rptr = temp2;
always@(posedge wclk)begin
	if(!wrst_n)begin	
		temp1 <= 0;
		temp2 <= 0;
	end
	else begin	
		temp1 <= rptr;
		temp2 <= temp1;
	end 
	end
endmodule

module fifo_mem #(parameter Data_Width = 8,
		parameter Addr_Width =4)
(input [Data_Width-1:0] w_data,
input [Addr_Width-1:0] w_addr,
input wclken,
input rempty,
input wclk,
input rclk,
output reg [Data_Width-1:0] r_data,
input [Addr_Width-1:0] r_addr);

reg [Data_Width-1:0] mem [(2**Addr_Width)-1:0];

always@(posedge wclk)begin
	if(wclken) begin
		mem[w_addr] <=w_data;
	end
end 
always@(posedge rclk) begin
	if(!wclken && !rempty)begin
		r_data <= mem[r_addr];
	end
end
endmodule

module fifo_m1 #(parameter Addr_Width = 4)
(input winc,
input [Addr_Width : 0] wq2_rptr,
input wclk,
input wrst_n,
output reg wfull,
output reg [Addr_Width :0] waddr,
output reg [Addr_Width :0] wptr);

reg [Addr_Width :0] wptr_bin;

always@(posedge wclk) begin
	if(!wrst_n)begin
		wptr_bin <= 0;
		waddr <=0;
		wfull <=0;
	end
	else if(winc && !wfull) begin
		wptr_bin <= wptr_bin + 1;
		waddr <= waddr+1;
	end
	else if(wptr[Addr_Width] != wq2_rptr[Addr_Width]) begin //not very sure about this condition
		wfull <= 1;
	end
end
assign wptr = wptr_bin ^ (wptr_bin >>1);
endmodule

module fifo_m2 #(parameter Addr_Width =4)
(input rinc,
input rclk,
input [Addr_Width :0] rq2_wptr,
input rrst_n,
output reg [Addr_Width :0] raddr,
output reg [Addr_Width :0] rptr,
output reg rempty);
reg [Addr_Width:0] rptr_bin;

always@(posedge rclk) begin
	if(!rrst_n) begin
		rptr_bin <=0;
		raddr <=0;
		rempty <=1;
	end
	else if(rinc && !rempty) begin		
		raddr <= raddr+1;
		rptr_bin <= rptr_bin+1;
	end
	else if(rptr_bin ^(rptr_bin>>1) == rq2_wptr) begin
		rempty <= 1;
	end
	else begin
		rempty <=0;
	end
end

assign rptr = rptr_bin ^ (rptr_bin >>1);
endmodule
	
	

