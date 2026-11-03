`timescale 1ns/1ps
module tb_idle_map_v14;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[63:0] raw=0;reg[3:0] cfg=0;reg diagnostic=0;
wire valid;wire signed[15:0] pcm;wire[7:0] held;wire[15:0] under;
pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(1)) dut(.extra_fx(2'b00),.map_enabled(1'b1),.keymap({8{7'd69}}),.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(1'b0),.test_mode(diagnostic),.test32(1'b0),.test_mask(4'hf),.expression_config(cfg),.mask32(~64'd0),.held(held),.monitor_valid(valid),.monitor_pcm(pcm),.underruns(under));
integer n,nonzero;
task collect;input integer count;input integer expect_zero;begin
nonzero=0;
for(n=0;n<count;n=n+1)begin
 @(negedge clk);while(!valid)@(negedge clk);
 if(^pcm===1'bx)$fatal(1,"unknown PCM");
 if(pcm!=0)nonzero=nonzero+1;
 if(expect_zero && pcm!==0)$fatal(1,"idle PCM=%0d",pcm);
end
end endtask
initial begin
repeat(4)@(negedge clk);rst=1;collect(64,1);
if(held!=0)$fatal(1,"cold idle held");$display("PASS cold idle 64 samples");$fflush();
raw=64'h1313131313131313;collect(64,1);if(held!=0)$fatal(1,"raw19 triggered");
$display("PASS all eight idle ADC inputs=19 remain silent");$fflush();
raw=180;collect(128,0);if(nonzero<64 || held!=1)$fatal(1,"pluck missing");
raw=0;collect(130,0);collect(32,1);if(held!=0)$fatal(1,"pluck held");
$display("PASS pluck pressure press / release zero");$fflush();
cfg=1;raw=180;collect(160,0);if(nonzero<64 || held!=1)$fatal(1,"flute missing");
raw=0;collect(520,0);collect(32,1);if(held!=0)$fatal(1,"flute held");
$display("PASS flute pressure press / release zero");$fflush();
diagnostic=1;collect(300,0);if(nonzero<100 || held!=15)$fatal(1,"FFT control missing");
if(under!=0)$fatal(1,"I2S underrun");
$display("PASS untouched FFT diagnostic produces sound intentionally; all cases zero underruns");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule

