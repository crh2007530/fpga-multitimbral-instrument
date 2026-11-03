// One read and one write per clock. Per-voice reset validity lives outside RAM.
module voice_state_ram #(parameter AW=5)(input clk,ren,wen,input[AW-1:0] ra,wa,input[35:0] d,output[35:0] q);
`ifdef __ICARUS__
`ifndef NATIVE_DPB
reg[35:0] mem[0:(1<<AW)-1],r;
always @(posedge clk)begin if(wen)mem[wa]<=d;if(ren)r<=mem[ra];end
assign q=r;
`else
`define VOICE_STATE_NATIVE
`endif
`else
`define VOICE_STATE_NATIVE
`endif
`ifdef VOICE_STATE_NATIVE
// GW5A maps the 36-bit parity primitive to two physical blocks.
// Keep the exact 36-bit word: low32 in one SDPB, high4 in small logic RAM.
wire[31:0] low_q;reg[(4*(1<<AW))-1:0]upper_bits;reg[3:0]upper_q;
always @(posedge clk)begin
 if(wen)upper_bits[wa*4+:4]<=d[35:32];
 if(ren)upper_q<=upper_bits[ra*4+:4];
end
assign q={upper_q,low_q};
SDPB #(.BIT_WIDTH_0(32),.BIT_WIDTH_1(32),.READ_MODE(0)) state_bram(
.DO(low_q),.DI(d[31:0]),.BLKSELA(3'd0),.BLKSELB(3'd0),
.ADA({{(9-AW){1'b0}},wa,5'b01111}),.ADB({{(9-AW){1'b0}},ra,5'd0}),
.CLKA(clk),.CLKB(clk),.CEA(wen),.CEB(ren),.OCE(1'b1),.RESET(1'b0));
`undef VOICE_STATE_NATIVE
`endif
endmodule
