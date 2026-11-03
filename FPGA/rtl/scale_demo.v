`timescale 1ns/1ps
// 450 ms note, 200 ms gap; an extra second after the high Do.
module scale_demo #(
    parameter integer ON_CYCLES=11070000,SLOT_CYCLES=15990000,PAUSE_CYCLES=24600000
)(input wire clk,rst_n,output reg [63:0] raw);
    reg [25:0] count;
    reg [2:0] note_index;
    wire [25:0] duration=(note_index==7) ? SLOT_CYCLES+PAUSE_CYCLES : SLOT_CYCLES;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin count<=0;note_index<=0;end
        else if(count==duration-1) begin count<=0;note_index<=note_index+1'b1;end
        else count<=count+1'b1;
    end
    always @* begin
        raw=0;
        if(rst_n && count<ON_CYCLES) raw[note_index*8+:8]=8'd220;
    end
endmodule
