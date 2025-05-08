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
 

