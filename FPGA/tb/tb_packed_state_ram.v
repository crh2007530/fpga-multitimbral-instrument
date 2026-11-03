`timescale 1ns/1ps
module tb_packed_state_ram;
reg clk=0;always #5 clk=~clk;
reg rst=0,ren=0,wen=0;reg[4:0]ra=0,wa=0;reg[35:0]d=0;
wire[35:0]q;reg[35:0]memory[0:31],expected;
GSR GSR(.GSRI(rst));
voice_state_ram #(.AW(5)) dut(clk,ren,wen,ra,wa,d,q);
integer i,checks=0;reg[31:0]rng=32'hcafe9821;reg verify=0;
always @(posedge clk)if(rst)begin
 if(ren)expected=memory[ra];
 if(wen)memory[wa]=d;
 #1;if(verify && ren)begin
 if(q!==expected)$fatal(1,"packed memory mismatch addr=%0d got=%h expected=%h",ra,q,expected);
 checks=checks+1;
 end
end
initial begin
repeat(4)@(negedge clk);rst=1;
for(i=0;i<32;i=i+1)begin wen=1;wa=i;d={4'hf,27'd0,wa};@(negedge clk);end
wen=0;verify=1;
for(i=0;i<20000;i=i+1)begin
 rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 ren=1;wen=rng[0];ra=rng[5:1];wa=i%3==0?ra:rng[10:6];d={rng[19:16],rng};
 @(negedge clk);
end
$display("PASS %0d native 36-bit packed memory comparisons; all high bits, same-address read-before-write and random dual-port access",checks);$finish;
end
endmodule
