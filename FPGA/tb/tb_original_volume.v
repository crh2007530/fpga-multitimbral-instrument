`timescale 1ns/1ps
module tb_original_volume;
    reg clk=0; always #20.325203252 clk=~clk;
    reg rst_n=0;
    reg [63:0] raw=0;
    reg [1:0] mode=0;
    wire [15:0] underruns;
    wire xsmt;
    integer checked_samples=0,nonzero=0;
    reg signed [15:0] expected;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1)) dut(
        .clk(clk),.rst_n(rst_n),.pressure_valid(8'hff),.pressure_raw(raw),
        .pitch_mode(mode),.underruns(underruns),.xsmt(xsmt));
    always @(posedge clk) if(rst_n && (&dut.note_valid)) begin
        expected=$signed(dut.sum)>>>2;
        #1;
        if(dut.mixed_pcm!==expected) $fatal(1,"original sum/4 mismatch got=%0d expected=%0d",dut.mixed_pcm,expected);
        checked_samples=checked_samples+1;
        if(expected!=0) nonzero=nonzero+1;
    end
    initial begin
        #1000;rst_n=1;raw=64'h1020304050607080;
        wait(checked_samples>=256);@(negedge clk);mode=1;raw={8{8'd255}};
        wait(checked_samples>=512);@(negedge clk);mode=2;
        wait(checked_samples>=768);@(negedge clk);raw=0;
        wait(checked_samples>=1024);
        if(dut.MASTER_SHIFT!=-2 || nonzero<500 || underruns!==0 || !xsmt)
            $fatal(1,"restored volume configuration/coverage failed");
        $display("PASS ORIGINAL VOLUME: default MASTER_SHIFT=-2, 1024 mixed PCM samples match original sum/4; all voices and 3 pitch banks, release, no underrun");
        $finish;
    end
    initial begin #50000000;$fatal(1,"timeout");end
endmodule
