`timescale 1ns/1ps
module tb_ram_phase_bank;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,bv=0,tm=0,ta=0;reg[4:0]bi=0;reg[31:0]inc=0;
reg[127:0]resets=0;wire[1279:0]addr;wire fault;
ram_phase_bank dut(clk,rst,ce,bv,bi,inc,tm,ta,resets,addr,fault);
`ifdef NATIVE_DPB
GSR GSR(.GSRI(rst));
`endif
reg[31:0]phase[0:127];reg[9:0]snapshot[0:127];integer i,f,c;reg[31:0]rng=32'hcafe1234;
function[31:0]ti;input integer index;reg[63:0]n;begin n=(64'd257+64'd83*index)*64'd4294967296;ti=(n*512+12300000)/24600000;end endfunction
function[31:0]base;input integer index;begin case(index%8)
0:base=46774041;1:base=52502086;2:base=58931599;3:base=62435854;
4:base=70081876;5:base=78664247;6:base=88297631;7:base=93548082;
endcase end endfunction
always @(posedge clk)begin
if(!rst)for(i=0;i<128;i=i+1)begin phase[i]=0;snapshot[i]=0;end
else begin
if(ce)for(i=0;i<128;i=i+1)snapshot[i]=phase[i][31:22];
for(i=0;i<128;i=i+1)begin
if(resets[i])phase[i]=0;
else if(bv && bi==i%32)phase[i]=phase[i]+(tm?(ta?ti(i):base(i)):(inc>>(i/32)));
end
end
end
initial begin
repeat(5)@(negedge clk);rst=1;
for(f=0;f<512;f=f+1)begin
tm=f%3!=0;ta=f%3==2;
for(c=0;c<128;c=c+1)begin
ce=c==0;bv=c>=6 && c<38;bi=c-6;inc=32'h1234567+(c-6)*32'h1020304;
rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};resets=0;
if(rng[2:0]==0)resets[rng[14:8]]=1;
// Include reset on snapshot and pitch update cycles, before/after RAM write.
if(c==6 && f%4==0)resets[0]=1;
if(c==40 && f%4==1)resets[64]=1;
if(c==0 && f%4==2)resets[127]=1;
@(negedge clk);
if(fault)$fatal(1,"scheduler overlap");
if(c==35)for(i=0;i<128;i=i+1)if(addr[i*10+:10]!==snapshot[i])$fatal(1,"snapshot differs frame=%d voice=%d got=%h expected=%h",f,i,addr[i*10+:10],snapshot[i]);
end
end
$display("PASS 512 frames x128 independent phases; 65536 snapshot comparisons against original register semantics; resets before/on/after pitch and RAM updates; diagnostic and musical pitches");$finish;
end
endmodule
