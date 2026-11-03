`timescale 1ns/1ps
module tb_all_pitch;
    reg clk=0;always #20.325203252 clk=~clk;
    reg rst=0,checking=0;
    reg [1:0] mode=0;
    reg [63:0] raw=0;
    wire [7:0] held;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1)) dut(
        .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.pitch_mode(mode),.held(held));
    function [31:0] base_inc;
        input integer ch;
        begin case(ch)
            0:base_inc=46774041;1:base_inc=52502086;2:base_inc=58931599;3:base_inc=62435854;
            4:base_inc=70081876;5:base_inc=78664247;6:base_inc=88297631;default:base_inc=93548082;
        endcase end
    endfunction
    genvar voice;
    generate for(voice=0;voice<8;voice=voice+1) begin: monitors
        reg [31:0] phase,step;
        reg ce;
        always @(posedge clk) if(checking) begin
            phase=dut.notes[voice].note.sine.phase_acc;
            ce=dut.sample_ce;
            step=(mode==1) ? (base_inc(voice)>>1) : (mode==2) ? (base_inc(voice)<<1) : base_inc(voice);
            if(dut.notes[voice].note.note_on!==0) $fatal(1,"pitch edit retriggered voice %0d",voice);
            #1;
            if(dut.notes[voice].note.sine.phase_acc!==(phase+(ce ? step : 32'd0)))
                $fatal(1,"voice %0d mode %0d phase/step mismatch",voice,mode);
        end
    end endgenerate
    integer ch;
    reg [7:0] expected;
    task select_bank;
        input [1:0] bank;
        begin @(negedge clk);mode=bank;repeat(7000) @(negedge clk);
            if(held!==255) $fatal(1,"pitch edit changed pressure holds");
        end
    endtask
    initial begin
        #1000;rst=1;repeat(300) @(negedge clk);mode=2;
        repeat(300) @(negedge clk);if(held!==0) $fatal(1,"touch alone starts voices");
        raw={8{8'd128}};repeat(10) @(negedge clk);checking=1;
        select_bank(0);select_bank(1);select_bank(2);select_bank(0);
        expected=255;
        for(ch=0;ch<8;ch=ch+1) begin
            @(negedge clk);raw[8*ch +: 8]=10;expected=expected & ~(8'b1<<ch);
            repeat(10) @(negedge clk);if(held!==expected) $fatal(1,"independent release %0d",ch);
        end
        $display("PASS ALL PITCH: 8 actual DDS phases, all 3 octave banks, continuous changes, no ADSR retrigger, unchanged holds, 8 independent releases, touch alone silent");
        $finish;
    end
    initial begin #5000000;$fatal(1,"timeout");end
endmodule
