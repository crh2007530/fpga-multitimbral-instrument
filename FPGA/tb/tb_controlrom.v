`timescale 1ns/1ps
module tb_controlrom;
reg clk=0;always #5 clk=~clk;
reg gsri=0;GSR GSR(.GSRI(gsri));
reg ena=0,enb=0;reg[9:0] ca=0,cb=0,pa=0,pb=0;wire[31:0] qa,qb;wire[15:0] pqa,pqb;
approved_control_rom dut(clk,ena,enb,ca,cb,pa,pb,qa,qb,pqa,pqb);
reg[31:0] curves[0:1023],ea,eb;reg[15:0] pitch[0:1023],epa,epb;integer i;
initial begin
$readmemh("assets/approved_envelopes.hex",curves);$readmemh("assets/approved_pitch_index.hex",pitch);#12;gsri=1;
for(i=0;i<4096;i=i+1)begin
@(negedge clk);ca=i;cb=1023-i;pa=i*3;pb=i*7;ena=i<1024 || i%3!=0;enb=i<1024 || i%5!=0;
if(ena)begin ea=curves[ca];epa=pitch[pa];end if(enb)begin eb=curves[cb];epb=pitch[pb];end
@(posedge clk);#1;if(qa!==ea || qb!==eb || pqa!==epa || pqb!==epb)$fatal(1,"control ROM mismatch %d",i);
end
$display("PASS native control DPB all 1024 curve/pitch addresses both ports and enable/hold");$finish;
end
endmodule
