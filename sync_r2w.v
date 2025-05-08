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