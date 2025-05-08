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
	
