`timescale 1ns/1ps
module tb_idle_visual_chain;
reg ac=0,sc=0,pc=0;always #20.325 ac=~ac;always #10 sc=~sc;always #6.734 pc=~pc;
reg rst=0;reg[63:0] raw=0;reg[3:0] cfg=0;reg testmode=0;
wire mv,vv;wire signed[15:0] mp;wire[15:0] vp;wire[7:0] held;wire[15:0] underruns;
pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1)) audio(
.clk(ac),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(1'b0),.test_mode(testmode),.test32(1'b0),.expression_config(cfg),.test_mask(4'hf),.mask32(~64'd0),.monitor_valid(mv),.monitor_pcm(mp),.held(held),.underruns(underruns));
sample_mailbox #(.WIDTH(16)) crossing(ac,rst,mv,mp,sc,rst,vv,vp);
reg frame=0;integer fc=0;always @(negedge pc)begin fc=fc+1;frame=(fc%10000==0);end
reg[9:0] idx=0;wire signed[8:0] displacement;wire wvisible;
video_wave_capture wave(sc,rst,vv,vp,pc,rst,frame,idx,displacement,wvisible);
reg[13:0] addr=0;wire dot,xvisible;
video_xy_capture xy(sc,rst,vv,vp,pc,rst,frame,addr,dot,xvisible);
integer n=0,nonzero=0,i,base;reg checkzero=0;
always @(negedge sc)if(rst && vv)begin
 n=n+1;if(n%256==0)begin $display("PROGRESS samples=%0d time=%0t",n,$time);$fflush();end if(^vp===1'bx)$fatal(1,"unknown PCM");
 if(vp!=0)nonzero=nonzero+1;
 if(checkzero && vp!==16'd0)$fatal(1,"idle PCM nonzero sample=%0d value=%0d",n,$signed(vp));
end
task samples;input integer count;integer start;begin start=n;wait(n>=start+count);end endtask
task inspect_zero;begin
 if(held!==0)$fatal(1,"idle held");
 if(!wvisible || !xvisible)$fatal(1,"no published frame");
 for(i=0;i<1024;i=i+1)begin @(negedge pc);idx=i;repeat(2)@(negedge pc);if(displacement!==0)$fatal(1,"idle wave %0d",i);end
 for(i=0;i<16384;i=i+1)begin @(negedge pc);addr=i;repeat(2)@(negedge pc);if(dot!==(i==8128))$fatal(1,"idle XY pixel %0d",i);end
end endtask
initial begin
 $display("START idle chain");$fflush();repeat(10)@(negedge ac);rst=1;checkzero=1;samples(2500);inspect_zero;
 $display("PASS cold idle: 2500 PCM samples zero, 1024 wave points zero, XY only (64,63)");
 raw=64'h0909090909090909;samples(2200);inspect_zero;
 $display("PASS all 8 raw=9 below release threshold: no false note, both graphics stationary");
 checkzero=0;raw=64'd180;base=nonzero;samples(1200);
 if(nonzero-base<100 || held!=1)$fatal(1,"pluck press missing");
 raw=0;samples(2500);checkzero=1;samples(200);inspect_zero;
 $display("PASS pluck press audible PCM, release settles both graphics to silence");
 checkzero=0;cfg=1;raw=180;base=nonzero;samples(1200);
 if(nonzero-base<100 || held!=1)$fatal(1,"flute press missing");
 raw=0;samples(2500);checkzero=1;samples(200);inspect_zero;
 $display("PASS flute press audible PCM, release settles both graphics to silence");
 checkzero=0;testmode=1;base=nonzero;samples(1200);
 if(nonzero-base<100)$fatal(1,"diagnostic tone absent");
 $display("PASS diagnostic positive control: untouched pressure still produces PCM as designed");
 if(underruns!=0)$fatal(1,"underrun");
 $display("PASS idle visual chain total samples=%0d underruns=%0d",n,underruns);$finish;
end
initial begin #1000;$display("AT 1us rst=%b mv=%b ce=%b",rst,mv,audio.sample_ce);$fflush();#9000;$display("AT 10us rst=%b mv=%b ce=%b n=%0d",rst,mv,audio.sample_ce,n);$fflush();#90000;$display("AT 100us n=%0d",n);$fflush();#400000000;$fatal(1,"timeout");end
endmodule




