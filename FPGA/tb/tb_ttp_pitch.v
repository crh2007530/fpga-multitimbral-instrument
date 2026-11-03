`timescale 1ns/1ps
module tb_ttp_pitch;
    reg clk=0;always #10 clk=~clk;
    reg rst=0,sdo=1;
    wire scl,valid;
    wire [7:0] keys;
    wire [1:0] mode;
    reg [15:0] touched=0;
    integer bitnum=0,frames=0;
    time last_edge=0;
    ttp229_pitch #(.START_CYCLES(50),.GAP_CYCLES(2000),.HALF_CYCLES(20)) dut(
        .clk(clk),.rst_n(rst),.sdo(sdo),.scl(scl),.keys(keys),.frame_valid(valid),.pitch_mode(mode));
    // Independent sensor model: changes data after the active falling edge.
    always @(negedge scl) if(rst) begin
        if($time-last_edge>5000) bitnum=0;
        #60;sdo=~touched[bitnum];bitnum=(bitnum+1)%16;last_edge=$time;
    end
    always @(posedge valid) frames=frames+1;
    task check;
        input [15:0] mask;input [1:0] expected;
        integer start;
        begin touched=mask;start=frames;wait(frames>=start+4);#50;
            if(mode!==expected || keys!==mask[7:0]) $fatal(1,"touch mask=%h keys=%h mode=%d expected=%d",mask,keys,mode,expected);
        end
    endtask
    initial begin
        #200;rst=1;
        check(0,0);check(1,1);check(0,1);check(2,0);check(4,2);check(0,2);
        check(3,2);check(16'hffff,2);check(16'h8000,2);check(1,1);
        rst=0;#100;if(mode!==0 || scl!==1) $fatal(1,"reset");
        $display("PASS TTP: active-low 16-bit scan, first/last bit, two-frame filter, retained selection, ambiguous input rejection, reset");$finish;
    end
    initial begin #5000000;$fatal(1,"timeout");end
endmodule
