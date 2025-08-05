// Testbench
module Top_tb;
  reg clk;
  reg rst;

  Top uut (
    .clk(clk),
    .rst(rst)
  );

  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, Top_tb);
    clk = 0;
    rst = 0;
    #10 rst = 1;
    #1000;
    $finish;
  end

  always #5 clk = ~clk;
endmodule

// Top-level Processor Module
module Top #(parameter DataWidth = 32, InstrWidth = 32, RegisterNum = 32) (
    input clk,
    input rst
);

wire [31:0] PCNext, PC, PCPlus4, PCTarget, ImmExt, Instr, RD1, RD2, Result, SrcA, SrcB, ALUResult, WriteData, ReadData;
wire PCSrc, RegWrite, ALUSrc, Zero, MemWrite, ResultSrc;
wire [1:0] ImmSrc;
wire [3:0] ALUControl;

assign SrcA = RD1;
assign WriteData = RD2;

mux1 muxpc(.PCSrc(PCSrc), .PCPlus4(PCPlus4), .PCTarget(PCTarget), .PCNext(PCNext));
PC pc(.clk(clk), .rst(rst), .PCNext(PCNext), .PC(PC));
Adder1 adder1(.PC(PC), .PCPlus4(PCPlus4));
InstrMem instrmem(.clk(clk), .rst(rst), .A(PC), .RD(Instr));
Adder2 adder2(.PC(PC), .ImmExt(ImmExt), .PCTarget(PCTarget));
Extend extend(.Instr(Instr), .ImmSrc(ImmSrc), .ImmExt(ImmExt));
RegFile regfile(.clk(clk), .rst(rst), .A1(Instr[19:15]), .A2(Instr[24:20]), .A3(Instr[11:7]), .WD3(Result), .WE3(RegWrite), .RD1(RD1), .RD2(RD2));
mux2 mux2ALU(.ALUSrc(ALUSrc), .RD2(RD2), .ImmExt(ImmExt), .SrcB(SrcB));
ALU alu(.SrcA(SrcA), .SrcB(SrcB), .ALUControl(ALUControl), .Zero(Zero), .ALUResult(ALUResult));
DataMem datamem(.clk(clk), .rst(rst), .A(ALUResult), .WD(WriteData), .WE(MemWrite), .RD(ReadData));
mux3 mux3res(.ResultSrc(ResultSrc), .ALUResult(ALUResult), .DataResult(ReadData), .Result(Result));
ControlUnit control(.op(Instr[6:0]), .funct3(Instr[14:12]), .funct7(Instr[30]), .Zero(Zero), .PCSrc(PCSrc), .ResultSrc(ResultSrc), .MemWrite(MemWrite), .ALUControl(ALUControl), .ALUSrc(ALUSrc), .ImmSrc(ImmSrc), .RegWrite(RegWrite));

endmodule
module mux1(input PCSrc, input [31:0] PCPlus4, PCTarget, output reg [31:0] PCNext);
always@(*) begin
    PCNext = PCSrc ? PCTarget : PCPlus4;
end
endmodule

module PC(input clk, rst, input [31:0] PCNext, output reg [31:0] PC);
always@(posedge clk or negedge rst) begin
    if (!rst) PC <= 0;
    else PC <= PCNext;
end
endmodule

module Adder1(input [31:0] PC, output [31:0] PCPlus4);
assign PCPlus4 = PC + 4;
endmodule

module RegFile #(parameter DataWidth = 32, parameter RegisterNum = 32) (
    input wire clk,
    input wire rst,
    input wire WE3,
    input wire [$clog2(RegisterNum)-1:0] A1,
    input wire [$clog2(RegisterNum)-1:0] A2,
    input wire [$clog2(RegisterNum)-1:0] A3,
    input wire [DataWidth-1:0] WD3,
    output wire [DataWidth-1:0] RD1,
    output wire [DataWidth-1:0] RD2
);

    reg [DataWidth-1:0] registers [RegisterNum-1:0];
    integer i =0;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < RegisterNum; i = i + 1)
                registers[i] <= 0;
        end else if (WE3 && A3 != 0) begin
            registers[A3] <= WD3;
        end
    end

    assign RD1 = registers[A1];
    assign RD2 = registers[A2];
endmodule

module Adder2(input [31:0] PC, ImmExt, output [31:0] PCTarget);
assign PCTarget = PC + ImmExt;
endmodule

module mux2(input ALUSrc, input [31:0] RD2, ImmExt, output reg [31:0] SrcB);
always@(*) begin
    SrcB = ALUSrc ? ImmExt : RD2;
end
endmodule

module mux3(input ResultSrc, input [31:0] ALUResult, DataResult, output reg [31:0] Result);
always@(*) begin
    Result = ResultSrc ? DataResult : ALUResult;
end
endmodule

module Extend(input [31:0] Instr, input [1:0] ImmSrc, output reg [31:0] ImmExt);
always @(*) begin
    case (ImmSrc)
        2'b00: ImmExt = {{20{Instr[31]}}, Instr[31:20]};
        2'b01: ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
        2'b10: ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0};
        default: ImmExt = 32'b0;
    endcase
end
endmodule




module ALU(input [31:0] SrcA, SrcB, input [3:0] ALUControl, output reg Zero, output reg [31:0] ALUResult);
always@(*) begin
    case(ALUControl)
        4'b0000: ALUResult = SrcA + SrcB; // ADD
        4'b0001: ALUResult = SrcA - SrcB; // SUB
        4'b0010: ALUResult = SrcA & SrcB; // AND
        4'b0011: ALUResult = SrcA | SrcB; // OR
        default: ALUResult = 32'b0;
    endcase
    Zero = (ALUResult == 0);
end
endmodule


module DataMem #(parameter Memsize = 1024, parameter DataWidth = 32)(
    input clk, rst, WE,
    input [DataWidth-1:0] WD, A,
    output [DataWidth-1:0] RD
);
reg [DataWidth-1:0] memory [0:Memsize-1];
always@(posedge clk or negedge rst) begin
    if (!rst) begin
        memory[0] <= 32'h00000000;
        memory[1] <= 32'h00000001; //just a random initialisation
        memory[2] <= 32'h00000002;
        memory[3] <= 32'h00000003;
        memory[4] <= 32'h00000004;
    end else if (WE) begin
        memory[A >> 2] <= WD;
    end
end
assign RD = memory[A >> 2];
endmodule

module InstrMem #(parameter Mem_size = 1024, parameter InstrWidth = 32)(
    input clk,
    input rst,
    input  [31:0] A,
    output reg [InstrWidth-1:0] RD
);
    reg [InstrWidth-1:0] memory [0:Mem_size-1];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            $readmemh("instr_mem.hex", memory);
        end

    end

    always @(*) begin
        RD = memory[A >> 2];
    end
endmodule

module ControlUnit(
    input [6:0] op,
    input [2:0] funct3,
    input funct7,
    input Zero,
    output reg PCSrc, ResultSrc, MemWrite, ALUSrc, RegWrite,
    output reg [1:0] ImmSrc,
    output reg [3:0] ALUControl
);
parameter ADD = 4'b0000, SUB = 4'b0001, AND = 4'b0010, OR = 4'b0011;

always@(*) begin
    case(op)
        7'b0110011: begin // R-type
            PCSrc = 0; ResultSrc = 0; MemWrite = 0;
            ALUSrc = 0; ImmSrc = 2'b00; RegWrite = 1;
            case ({funct7, funct3})
                4'b000_000: ALUControl = ADD;
                4'b010_000: ALUControl = SUB;
                4'b000_111: ALUControl = AND;
                4'b000_110: ALUControl = OR;
                default:    ALUControl = ADD;
            endcase
        end
        7'b0010011: begin // I-type
            PCSrc = 0; ResultSrc = 0; MemWrite = 0;
            ALUSrc = 1; ImmSrc = 2'b00; RegWrite = 1;
            case (funct3)
                3'b000: ALUControl = ADD; // addi
                3'b111: ALUControl = AND; // andi
                3'b110: ALUControl = OR;  // ori
                default: ALUControl = ADD;
            endcase
        end
        7'b0000011: begin // Load
            PCSrc = 0; ResultSrc = 1; MemWrite = 0;
            ALUSrc = 1; ImmSrc = 2'b00; RegWrite = 1;
            ALUControl = ADD; // use ADD to calculate address
        end
        7'b0100011: begin // Store
            PCSrc = 0; ResultSrc = 0; MemWrite = 1;
            ALUSrc = 1; ImmSrc = 2'b01; RegWrite = 0;
            ALUControl = ADD; // use ADD to calculate address
        end
        7'b1100011: begin // Branch (beq)
            PCSrc = Zero ? 1 : 0; ResultSrc = 0; MemWrite = 0;
            ALUSrc = 0; ImmSrc = 2'b10; RegWrite = 0;
            ALUControl = SUB; // use SUB to compare
        end
        default: begin
            PCSrc = 0; ResultSrc = 0; MemWrite = 0; ALUSrc = 0; RegWrite = 0;
            ALUControl = ADD; ImmSrc = 2'b00;
        end
    endcase
end
endmodule
