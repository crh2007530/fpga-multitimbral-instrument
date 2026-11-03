`timescale 1ns/1ps
module tb_web_bank;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,piano=0,guitar=0,diag=0;
reg[639:0]addresses=0;reg[1023:0]forces=0,envelopes=0,steps=0;reg[63:0]gates=0;
wire[1023:0]samples;wire valid;
shared_voice_bank #(.VOICES(64),.GROUP(32),.THIRD_TIMBRE(1)) dut(clk,rst,ce,guitar,addresses,forces,envelopes,samples,valid,piano,diag,steps,gates);
reg[95:0]vectors[0:16383];reg[51:0]expected[0:16383];reg[95:0]r;reg[51:0]e;
integer frame,i,age;reg[4:0] seed_slot;reg[35:0] seed0,seed1;
initial begin
$readmemh("checks/web_inputs.hex",vectors);$readmemh("checks/web_expected.hex",expected);
repeat(4)@(negedge clk);rst=1;
for(frame=0;frame<256;frame=frame+1)begin
 @(negedge clk);piano=frame%4==2;guitar=frame%4==1;diag=frame%4==3;
 for(i=0;i<64;i=i+1)begin
 r=vectors[frame*64+i];addresses[i*10+:10]=r[93:84];envelopes[i*16+:16]=r[83:68];forces[i*16+:16]=r[67:52];steps[i*16+:16]=r[51:36];gates[i]=r[0];
 end
 force dut.instruments.lanes[0].state_write=1;
 force dut.instruments.lanes[1].state_write=1;
 force dut.instruments.lanes[0].state_write_slot=seed_slot;
 force dut.instruments.lanes[1].state_write_slot=seed_slot;
 force dut.instruments.lanes[0].state_write_data=seed0;
 force dut.instruments.lanes[1].state_write_data=seed1;
 for(i=0;i<32;i=i+1)begin
 @(negedge clk);seed_slot=i;r=vectors[frame*64+i];seed0={1'b0,r[35:18],r[1],r[17:2]};r=vectors[frame*64+i+32];seed1={1'b0,r[35:18],r[1],r[17:2]};
 end
 @(negedge clk);
 release dut.instruments.lanes[0].state_write;release dut.instruments.lanes[1].state_write;
 release dut.instruments.lanes[0].state_write_slot;release dut.instruments.lanes[1].state_write_slot;
 release dut.instruments.lanes[0].state_write_data;release dut.instruments.lanes[1].state_write_data;
 ce=1;@(negedge clk);ce=0;age=1;
 while(!valid && age<100)begin @(negedge clk);age=age+1;end
 if(age!=75 || !valid)$fatal(1,"publication age=%0d",age);
 for(i=0;i<64;i=i+1)begin
 e=expected[frame*64+i];
 if(samples[i*16+:16]!==e[15:0])$fatal(1,"sample frame=%0d voice=%0d got=%0d expected=%0d",frame,i,$signed(samples[i*16+:16]),$signed(e[15:0]));
`ifdef NATIVE_DPB
 if(i<32)r=dut.instruments.lanes[0].state_ram.state_bram.ram_MEM[i*36+:36];
 else r=dut.instruments.lanes[1].state_ram.state_bram.ram_MEM[(i-32)*36+:36];
`else
 if(i<32)r=dut.instruments.lanes[0].state_ram.mem[i];else r=dut.instruments.lanes[1].state_ram.mem[i-32];
`endif
 if(r[34:17]!==e[49:32] || r[15:0]!==e[31:16])$fatal(1,"stored state frame=%d voice=%d",frame,i);
 end
 repeat(5)@(negedge clk);
end
$display("PASS 16384 independent Python reference vectors: both parallel lanes, all64 voices, all envelope/guitar knot boundaries, signed FM, interpolation, retrigger and 75-cycle publication");$finish;
end
endmodule

