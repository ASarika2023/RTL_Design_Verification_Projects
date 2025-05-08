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
