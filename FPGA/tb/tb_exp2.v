`timescale 1ns/1ps
module tb_exp2;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,glide=0,vibrato=0;
reg [31:0] target=100000000;
wire signed [4:0] lfo;wire [31:0] inc;
expression_lfo l(.clk(clk),.rst_n(rst),.sample_ce(ce),.level(lfo));
expression_pitch p(.clk(clk),.rst_n(rst),.sample_ce(ce),.glide(glide),.vibrato(vibrato),.target(target),.lfo(lfo),.phase_inc(inc));
reg clear=0,testmode=0;reg [5:0] events=0;wire [3:0] cfg;
expression_controls c(.clk(clk),.rst_n(rst),.clear(clear),.test_mode(testmode),.events(events),.config_bits(cfg));
reg echo_en=0,vin=0;reg signed [15:0] pcm=0;wire vout;wire signed [15:0] out;
audio_echo #(.ADDR_BITS(3)) echo(.clk(clk),.rst_n(rst),.enable(echo_en),.input_valid(vin),.input_pcm(pcm),.output_valid(vout),.output_pcm(out));
task frame;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
task impulse_sample;
input integer x,expected;
begin @(negedge clk);vin=1;pcm=x;@(negedge clk);vin=0;
 @(negedge clk);if(!vout || out!==expected)$fatal(1,"echo x=%d output=%d expected=%d",x,out,expected);
 @(negedge clk);if(vout)$fatal(1,"duplicated sample");end
endtask
integer i;reg [31:0] prev;reg signed [4:0] low,high;
initial begin
 repeat(4)@(negedge clk);rst=1;frame;
 if(inc!=target)$fatal(1,"bypass pitch");
 glide=1;target=200000000;prev=inc;
 for(i=0;i<8000;i=i+1)begin frame;if(inc<prev || inc>target)$fatal(1,"glide monotonic/bounds");prev=inc;end
 if(inc!=target)$fatal(1,"glide convergence");
 target=50000000;prev=inc;
 for(i=0;i<8000;i=i+1)begin frame;if(inc>prev || inc<target)$fatal(1,"down glide");prev=inc;end
 if(inc!=target)$fatal(1,"down convergence");
 glide=0;vibrato=1;low=0;high=0;
 for(i=0;i<10000;i=i+1)begin frame;
 if(lfo<low)low=lfo;if(lfo>high)high=lfo;
 if(inc<target-target/128-16 || inc>target+target/128+16)$fatal(1,"vibrato bounds");end
 if(low!= -8 || high!=8)$fatal(1,"LFO range");
 events=1;@(negedge clk);events=0;@(negedge clk);if(cfg!=1)$fatal(1,"timbre");
 events=4;@(negedge clk);events=0;@(negedge clk);if(cfg!=3)$fatal(1,"glide UI");
 events=8;@(negedge clk);events=0;@(negedge clk);if(cfg!=7)$fatal(1,"vibrato UI");
 events=2;@(negedge clk);events=0;@(negedge clk);if(cfg!=15)$fatal(1,"echo UI");
 testmode=1;events=15;@(negedge clk);events=0;@(negedge clk);if(cfg!=15)$fatal(1,"test mode changed state");
 clear=1;@(negedge clk);clear=0;@(negedge clk);if(cfg!=0)$fatal(1,"restore");
 impulse_sample(1234,1234);impulse_sample(-32768,-32768);
 echo_en=1;impulse_sample(16000,16000);
 for(i=1;i<8;i=i+1)impulse_sample(0,0);
 impulse_sample(0,4000);
 for(i=1;i<8;i=i+1)impulse_sample(0,0);
 impulse_sample(0,2000);
 echo_en=0;impulse_sample(1000,1000);
 echo_en=1;for(i=0;i<24;i=i+1)impulse_sample(0,0);
 // Sustained full-scale feedback must saturate, never wrap in sign.
 for(i=0;i<24;i=i+1)impulse_sample(32767,32767);
 echo_en=0;impulse_sample(0,0);
 echo_en=1;for(i=0;i<24;i=i+1)impulse_sample(-32768,-32768);
 $display("PASS EXP2 glide convergence, vibrato range, independent controls/test bypass, echo impulse/tail/re-enable/saturation");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
