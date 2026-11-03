`timescale 1ns/1ps
module tb_fft_mode;
reg clk=0;always #5 clk=~clk;
reg rst=0,testmode=1;reg [3:0] mask=15,div=0;
always @(posedge clk)div<=div+1'b1;
wire ce=div==15;initial force dut.sample_ce=ce;
pcm_pressure_poly8 #(.PER_VOICE(1),.DYNAMIC_PITCH(1)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'd0),.voice_modes(16'haaaa),.test_mode(testmode),.test_mask(mask),.pitch_mode(2'd2));
integer fd,n,k;reg capture=0;
always @(negedge clk)if(capture && dut.mixed_valid)$fdisplay(fd,"%0d",$signed(dut.mixed_pcm));
task samples;input integer cnt;integer j;begin for(j=0;j<cnt;j=j+1)begin @(posedge ce);@(negedge clk);end end endtask
initial begin
 fd=$fopen("validation_new/fft_pcm.txt","w");repeat(4)@(negedge clk);rst=1;
 for(k=0;k<5;k=k+1)begin
  mask=k==0?15:(15^(1<<(k-1)));samples(5000);
  if(dut.held!=={4'b0,mask})$fatal(1,"test held");
  capture=1;samples(8192);capture=0;
 end
 testmode=0;samples(5000);if(dut.held!==0 || dut.mixed_pcm!==0)$fatal(1,"test exit silence");
 $fclose(fd);$display("PASS FFT mode: 4 fixed pure tones, individual mutes, exit returns to pressure and silence; PCM for numerical spectrum analysis (accelerated sample CE, not timing evidence)");$finish;
end
endmodule
