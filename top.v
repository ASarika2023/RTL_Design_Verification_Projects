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

