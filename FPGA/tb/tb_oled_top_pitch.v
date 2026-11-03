`timescale 1ns/1ps
module tb_oled_top_pitch;
    reg clk=0; always #10 clk=~clk;
    reg [1:0] mode=0;
    reg [7:0] held=0;
    tri1 a,b,c,d,scl,sda;
    pressure_poly8_top dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),
        .adc1_scl(c),.adc1_sda(d),.oled_scl(scl),.oled_sda(sda),.ttp_sdo(1'b1));
    task settle; begin repeat(20) @(negedge clk); end endtask
    initial begin
        force dut.pitch_mode=mode;
        force dut.pressure_held=held;
        repeat(300) @(negedge clk);
        if(dut.display_status.octave!==0 || dut.z1_note!==72) $fatal(1,"default C5");
        held=1; settle;
        if(dut.history_records[6:0]!==72 || dut.history_count!==1) $fatal(1,"C5 press event");
        mode=1; settle;
        if(dut.display_status.octave!==1 || dut.z1_note!==60 || dut.history_count!==1)
            $fatal(1,"live C4 selection/retrigger");
        held=0; settle;
        if(dut.history_records[6:0]!==60 || dut.history_records[7]!==0) $fatal(1,"C4 release");
        mode=2; held=3; settle;
        if(dut.history_records[6:0]!==86 || dut.history_records[34:28]!==84)
            $fatal(1,"C6 Z1 / D6 Z2 simultaneous events");
        held=0; settle;
        mode=0; settle;
        if(dut.z1_note!==72 || dut.history_count!==6) $fatal(1,"restore C5 / count");
        $display("PASS OLED TOP: pitch wiring, live changes, event MIDI, simultaneous Z1/Z2, release");
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
