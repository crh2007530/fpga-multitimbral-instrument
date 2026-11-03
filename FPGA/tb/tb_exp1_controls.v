`timescale 1ns/1ps
module tb_exp1_controls;
reg clk=0;always #5 clk=~clk;reg rst=0,valid=0;reg[7:0] keys=0;
wire[15:0] modes;wire[3:0] sel,mask;wire testmode,chord,fft32;wire[4:0] target;wire[31:0] mask32;
performance_controls #(.EXPANSION(1)) dut(.clk(clk),.rst_n(rst),.frame_valid(valid),.keys(keys),.modes(modes),.selected(sel),.test_mode(testmode),.test_mask(mask),.chord_mode(chord),.test32(fft32),.selected_test(target),.mask32(mask32));
task frame;input[7:0]k;begin @(negedge clk);keys=k;valid=1;@(negedge clk);valid=0;end endtask
task key;input[7:0]k;begin frame(0);frame(0);frame(k);frame(k);end endtask
integer i;reg[31:0]expected;
initial begin repeat(3)@(negedge clk);rst=1;
 if(chord||fft32||testmode||sel!=8)$fatal(1,"startup");
 key(16);if(!testmode||fft32||mask!=15)$fatal(1,"legacy FFT4");key(128);
 key(32);if(!chord||testmode)$fatal(1,"chord toggle");
 // Holding key6 does not repeatedly toggle.
 repeat(20)frame(32);if(!chord)$fatal(1,"held chord key");
 key(16);if(!testmode||!fft32||target!=0||mask32!==32'hffffffff)$fatal(1,"enter32");
 expected=32'hffffffff;
 for(i=0;i<32;i=i+1)begin
 if(target!=i)$fatal(1,"selection %d",i);
 key(32);expected[i]=0;if(mask32!==expected)$fatal(1,"independent mute %d",i);
 key(8);
 end
 if(target!=0||mask32!=0)$fatal(1,"wrap32/all mute");
 key(64);if(mask32!==32'hffffffff)$fatal(1,"restore32");
 key(1);if(modes!=0)$fatal(1,"fixed test pitch");
 key(16);if(testmode||fft32||!chord)$fatal(1,"return chord");
 key(8);key(4);if(modes!==8)$fatal(1,"pad pitch selection");
 key(128);if(testmode||chord||fft32||modes||sel!=8)$fatal(1,"safe restore");
 $display("PASS expansion controls: FFT4 retained, chord toggle, all32 individual mute/selection/wrap, restore, fixed test pitch, safe basic return");$finish;
end endmodule
