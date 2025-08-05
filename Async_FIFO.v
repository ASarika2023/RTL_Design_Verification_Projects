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
uart_fifo #(Addr_Width, Data_Width) dut (
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


// Code your design here
module uart_fifo #(parameter Addr_Width = 4, parameter Data_Width = 8)(
    input wclk,
    input wrst_n,
    input rclk,
    input rrst_n,
    input [Data_Width-1:0] wdata,
    input winc,
    input rinc,
    output [Data_Width-1:0] rdata,
    output rempty,
    output wfull
);

    wire [Addr_Width:0] rptr, wptr, wq2_rptr, rq2_wptr;
    wire [Addr_Width-1:0] waddr, raddr;
    
  
  wire wclken = winc && !wfull;

    fifo_mem #(Data_Width, Addr_Width) mem (
        .w_data(wdata),
        .w_addr(waddr),
        .wclken(wclken),
        .wclk(wclk),
        .rclk(rclk),
        .r_data(rdata),
        .r_addr(raddr)
    );

    sync_r2w #(Addr_Width) sync_r2w_inst (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .rptr(rptr),
        .wq2_rptr(wq2_rptr)
    );

    sync_w2r #(Addr_Width) sync_w2r_inst (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .wptr(wptr),
        .rq2_wptr(rq2_wptr)
    );

    fifo_write_ctrl #(Addr_Width) fw (
        .winc(winc),
        .wq2_rptr(wq2_rptr),
        .wclk(wclk),
        .wrst_n(wrst_n),
        .wfull(wfull),
        .waddr(waddr),
        .wptr(wptr)
    );

    fifo_read_ctrl #(Addr_Width) fr (
        .rinc(rinc),
        .rclk(rclk),
        .rq2_wptr(rq2_wptr),
        .rrst_n(rrst_n),
        .raddr(raddr),
        .rptr(rptr),
        .rempty(rempty)
    );

endmodule



module fifo_mem #(parameter Data_Width = 8, parameter Addr_Width = 4)(
    input [Data_Width-1:0] w_data,
    input [Addr_Width-1:0] w_addr,
    input wclken,
    input wclk,
    input rclk,
    output reg [Data_Width-1:0] r_data,
    input [Addr_Width-1:0] r_addr
);
  reg [Data_Width-1:0] mem [(2**Addr_Width)-1:0]; 
 
    always @(posedge wclk) begin
        if (wclken)
            mem[w_addr] <= w_data;
    end

    always @(posedge rclk) begin
      r_data <= mem[r_addr];
    end
endmodule


module sync_r2w #(parameter Addr_Width = 4)(
    input wclk,
    input wrst_n,
    input [Addr_Width:0] rptr,
    output reg [Addr_Width:0] wq2_rptr
);
  reg [Addr_Width:0] temp1, temp2;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            temp1 <= 0;
          	temp2 <=0;
            wq2_rptr <= 0;
        end else begin
            temp1 <= rptr;
          	temp2 <= temp1;
            wq2_rptr <= temp2;
        end
    end
endmodule


module sync_w2r #(parameter Addr_Width = 4)(
    input rclk,
    input rrst_n,
    input [Addr_Width:0] wptr,
    output reg [Addr_Width:0] rq2_wptr
);
  reg [Addr_Width:0] temp1, temp2;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            temp1 <= 0;
          	temp2 <= 0;
            rq2_wptr <= 0;
        end else begin
            temp1 <= wptr;
          	temp2 <= temp1;
            rq2_wptr <= temp2;
        end
    end
endmodule


module fifo_write_ctrl #(parameter Addr_Width = 4)(
    input winc,
    input [Addr_Width:0] wq2_rptr,
    input wclk,
    input wrst_n,
    output reg wfull,
    output [Addr_Width-1:0] waddr,
    output reg [Addr_Width:0] wptr
);
    reg [Addr_Width:0] wptr_bin;

  assign waddr = wptr_bin[Addr_Width-1:0]; //last bit only to check for full condition
  
  wire [Addr_Width:0] wptr_gray_next = (wptr_bin + 1) ^ ((wptr_bin + 1) >> 1); 
  
    wire full_cond = (wptr_gray_next[Addr_Width] != wq2_rptr[Addr_Width]) &&
                     (wptr_gray_next[Addr_Width-1:0] == wq2_rptr[Addr_Width-1:0]);

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
          
            wptr_bin <= 0;
            wptr <= 0;
            wfull <= 0;
        end else begin
            if (winc && !wfull)
                wptr_bin <= wptr_bin + 1;

            wptr <= wptr_bin ^ (wptr_bin >> 1);
            wfull <= full_cond;
        end
    end
endmodule


module fifo_read_ctrl #(parameter Addr_Width = 4)(
    input rinc,
    input rclk,
  input [Addr_Width:0] rq2_wptr, //gray code pointer from the write domain
    input rrst_n,
    output [Addr_Width-1:0] raddr,
  output reg [Addr_Width:0] rptr, //gray code pointer to the write domain
    output reg rempty
);
    reg [Addr_Width:0] rptr_bin;

    assign raddr = rptr_bin[Addr_Width-1:0];
    wire [Addr_Width:0] rptr_gray_next = (rptr_bin + 1) ^ ((rptr_bin + 1) >> 1);
    wire empty_cond = (rptr_gray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin <= 0;
            rptr <= 0;
            rempty <= 1;
        end else begin
            if (rinc && !rempty)
                rptr_bin <= rptr_bin + 1;
          		rptr <= rptr_bin ^ (rptr_bin >> 1); //only output
                rempty <= empty_cond;
        end
    end
endmodule
