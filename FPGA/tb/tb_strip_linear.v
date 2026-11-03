`timescale 1ns/1ps
module tb_strip_linear;
    reg clk=0,rst_n=0;
    always #10 clk=~clk;
    reg [63:0] pressure=0;
    wire dout;
    wire [719:0] pixels;
    wire [31:0] frames;
    ws2812_30led_driver dut(.clk(clk),.rst_n(rst_n),
        .p1(pressure[7:0]),.p2(pressure[15:8]),.p3(pressure[23:16]),.p4(pressure[31:24]),
        .p5(pressure[39:32]),.p6(pressure[47:40]),.p7(pressure[55:48]),.p8(pressure[63:56]),.dout(dout));
    ws2812_monitor monitor(dout,pixels,frames);
    function [23:0] color;
        input integer region;
        input [7:0] value;
        reg [7:0] b;
        begin
            b=(value<=10)?0:value;
            case(region)
                0:color={8'd0,b,8'd0}; 1:color={b,8'd0,8'd0};
                2:color={8'd0,8'd0,b}; 3:color={b,b,8'd0};
                4:color={b,8'd0,b}; 5:color={8'd0,b,b};
                6,7:color={b,b,b}; default:color=0;
            endcase
        end
    endfunction
    task check;
        integer led;
        reg [23:0] expected;
        begin
            #3500000;
            for(led=0;led<30;led=led+1) begin
                if(led<24) expected=color(led/3,pressure[(led/3)*8+:8]);else expected=0;
                if(pixels[led*24+:24]!==expected)
                    $fatal(1,"Linear brightness mismatch LED %0d got %h expected %h",led,pixels[led*24+:24],expected);
            end
        end
    endtask
    integer v,ch;
    initial begin
        #100;rst_n=1;
        // Exhaust all 256 raw ADC codes, decoded from all eight physical zones.
        for(v=0;v<256;v=v+1) begin
            pressure={8{v[7:0]}};check;
        end
        pressure=64'hff80400b0a090100;check;
        // Independent zone mapping, not only simultaneous equal pressures.
        for(ch=0;ch<8;ch=ch+1) begin
            pressure=0;pressure[ch*8+:8]=8'd128;check;
        end
        pressure=0;check;
        $display("PASS STRIP: all 256 pressure codes, 0..10 off / 11 on, eight independent regions, GRB, 30 LEDs, 400/800 ns and reset; frames=%0d",frames);
        $finish;
    end
    initial begin #1000000000;$fatal(1,"Strip timeout");end
endmodule

