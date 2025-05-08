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

	

  
