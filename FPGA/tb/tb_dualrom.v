`timescale 1ns/1ps
module tb_dualrom;
reg clk=0;always #5 clk=~clk;
reg gsri=0;GSR GSR(.GSRI(gsri));
reg ena=0,enb=0;reg[12:0] addra=0,addrb=0;wire[15:0] qa,qb;
approved_wave_rom dut(clk,ena,enb,addra,addrb,qa,qb);
reg[15:0] mem[0:8191],ea,eb;integer i;
initial begin
$readmemh("assets/approved_oscillators.hex",mem);#12;gsri=1;
for(i=0;i<32768;i=i+1)begin
@(negedge clk);addra=i%8192;addrb=(8191-i)%8192;ena=(i<8192)||(i%3!=0);enb=(i<8192)||(i%5!=0);
if(ena)ea=mem[addra];if(enb)eb=mem[addrb];
@(posedge clk);#1;if(qa!==ea || qb!==eb)$fatal(1,"ROM mismatch i=%d a=%h/%h b=%h/%h",i,qa,ea,qb,eb);
end
$display("PASS native DPB both ports 8192 addresses, 32768 enable/hold cycles");$finish;
end
endmodule
