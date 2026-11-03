`timescale 1ns/1ps
`include "tb/reference_pitch_v40.v"
module tb_compact_pitch_equivalence;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,glide=0,vibrato=0,map=0,diag=0,alltest=0;
reg[1023:0]targets=0;reg signed[4:0]lfo=0;reg[55:0]notes=0;reg[15:0]modes=0;
wire av,bv,ab,bb,ao,bo;wire[4:0]ai,bi;wire[31:0]ax,bx;
shared_pitch_engine #(.CUSTOM_MAP(1),.COMPACT_TARGETS(1)) a(clk,rst,ce,glide,vibrato,targets,lfo,av,ai,ax,ab,ao,map,notes,modes,diag,alltest);
reference_pitch_v40 #(.CUSTOM_MAP(1)) b(clk,rst,ce,glide,vibrato,targets,lfo,bv,bi,bx,bb,bo,map,notes,modes);
function[31:0] chord_target;input[4:0] index;begin case(index)
5'd0:chord_target=32'd46774041;
5'd1:chord_target=32'd52502086;
5'd2:chord_target=32'd58931599;
5'd3:chord_target=32'd62435854;
5'd4:chord_target=32'd70081876;
5'd5:chord_target=32'd78664247;
5'd6:chord_target=32'd88297631;
5'd7:chord_target=32'd93548082;
5'd8:chord_target=32'd58931599;
5'd9:chord_target=32'd66148483;
5'd10:chord_target=32'd74249162;
5'd11:chord_target=32'd78664247;
5'd12:chord_target=32'd88297631;
5'd13:chord_target=32'd99110741;
5'd14:chord_target=32'd111248044;
5'd15:chord_target=32'd117863198;
5'd16:chord_target=32'd70081877;
5'd17:chord_target=32'd78664247;
5'd18:chord_target=32'd88297632;
5'd19:chord_target=32'd93548082;
5'd20:chord_target=32'd105004171;
5'd21:chord_target=32'd117863198;
5'd22:chord_target=32'd132296965;
5'd23:chord_target=32'd140163753;
5'd24:chord_target=32'd93548082;
5'd25:chord_target=32'd105004172;
5'd26:chord_target=32'd117863198;
5'd27:chord_target=32'd124871708;
5'd28:chord_target=32'd140163752;
5'd29:chord_target=32'd157328494;
5'd30:chord_target=32'd176595262;
5'd31:chord_target=32'd187096164;
default:chord_target=0;endcase end endfunction
function[31:0] diagnostic_target;input[4:0] index;begin case(index)
5'd0:diagnostic_target=32'd22973536;
5'd1:diagnostic_target=32'd30393004;
5'd2:diagnostic_target=32'd37812473;
5'd3:diagnostic_target=32'd45231942;
5'd4:diagnostic_target=32'd52651410;
5'd5:diagnostic_target=32'd60070879;
5'd6:diagnostic_target=32'd67490348;
5'd7:diagnostic_target=32'd74909817;
5'd8:diagnostic_target=32'd82329285;
5'd9:diagnostic_target=32'd89748754;
5'd10:diagnostic_target=32'd97168223;
5'd11:diagnostic_target=32'd104587691;
5'd12:diagnostic_target=32'd112007160;
5'd13:diagnostic_target=32'd119426629;
5'd14:diagnostic_target=32'd126846098;
5'd15:diagnostic_target=32'd134265566;
5'd16:diagnostic_target=32'd141685035;
5'd17:diagnostic_target=32'd149104504;
5'd18:diagnostic_target=32'd156523972;
5'd19:diagnostic_target=32'd163943441;
5'd20:diagnostic_target=32'd171362910;
5'd21:diagnostic_target=32'd178782379;
5'd22:diagnostic_target=32'd186201847;
5'd23:diagnostic_target=32'd193621316;
5'd24:diagnostic_target=32'd201040785;
5'd25:diagnostic_target=32'd208460253;
5'd26:diagnostic_target=32'd215879722;
5'd27:diagnostic_target=32'd223299191;
5'd28:diagnostic_target=32'd230718659;
5'd29:diagnostic_target=32'd238138128;
5'd30:diagnostic_target=32'd245557597;
5'd31:diagnostic_target=32'd252977066;
default:diagnostic_target=0;endcase end endfunction

integer count=0,f,j,k;reg[31:0]rng=32'h348c6abc;reg[31:0]value;
task next_random;begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};end endtask
task set_targets;begin for(k=0;k<32;k=k+1)begin
 value=chord_target(k);
 targets[k*32+:32]=diag?(alltest?diagnostic_target(k):chord_target(k%8)):
 modes[(k%8)*2+:2]==1?(value>>1):modes[(k%8)*2+:2]==2?(value<<1):value;
end end endtask
always @(posedge clk)begin #1;if(rst)begin
 if({av,ab,ao}!=={bv,bb,bo})$fatal(1,"control mismatch");
 if(av)begin if({ai,ax}!=={bi,bx})$fatal(1,"pitch mismatch %0d",count);count=count+1;end
end end
initial begin
repeat(4)@(negedge clk);rst=1;
for(f=0;f<4096;f=f+1)begin
 next_random;{map,glide,vibrato,diag,alltest}=rng[4:0];lfo=rng[9:5];modes=rng[25:10];
 for(j=0;j<8;j=j+1)begin next_random;notes[j*7+:7]=rng[6:0];end
 set_targets;ce=1;@(negedge clk);ce=0;
 for(j=0;j<63;j=j+1)begin
  if(j==8)begin next_random;modes=rng[15:0];diag=rng[16];alltest=rng[17];set_targets;end
  if(j==12 && f%17==0)ce=1;else ce=0;
  if(j==23 && f%129==0)rst=0;else rst=1;
  @(negedge clk);
 end
end
$display("PASS compact 18-bit target controls versus V40: %0d results,4096 randomized frames,modes,diagnostic,custom map,glide,vibrato,live changes,overlap,reset",count);$finish;
end
endmodule
