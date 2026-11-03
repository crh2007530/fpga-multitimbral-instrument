`timescale 1ns/1ps
// Standard I2S, 32 bit slots; mono 16 bit PCM duplicated in L/R.
// Request 96 clocks before frame latch; the timbre pipeline must finish before this deadline.
module i2s_tx #(parameter integer REQUEST_BIT=51)(input wire clk,rst_n,
    input wire signed [15:0] sample_data,input wire sample_valid,
    output wire control_ce,output wire sample_ce,output reg bclk,lrclk,din,
    output reg [15:0] underruns);
    reg [2:0] divider;
    reg [5:0] bit_index;
    reg signed [15:0] next_sample,frame_sample;
    reg fresh,started;
    wire [5:0] next_bit=bit_index+6'd1;
    assign control_ce=rst_n && divider==7 && bit_index==REQUEST_BIT-1;
    assign sample_ce=rst_n && divider==7 && bit_index==REQUEST_BIT;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            divider<=0;bit_index<=63;next_sample<=0;frame_sample<=0;
            bclk<=0;lrclk<=0;din<=0;fresh<=0;started<=0;underruns<=0;
        end else begin
            divider<=divider+3'd1;
            if(sample_valid) begin next_sample<=sample_data;fresh<=1;end
            if(divider==3) bclk<=1;
            if(divider==7) begin
                bclk<=0;bit_index<=next_bit;
                if(next_bit==0) begin
                    lrclk<=0;din<=0;frame_sample<=fresh ? next_sample : 16'sd0;
                    if(started && !fresh && underruns!=65535) underruns<=underruns+16'd1;
                    started<=1;fresh<=0;
                end else if(next_bit==32) begin lrclk<=1;din<=0;end
                else if(next_bit>=1 && next_bit<=16) din<=frame_sample[16-next_bit];
                else if(next_bit>=33 && next_bit<=48) din<=frame_sample[48-next_bit];
                else din<=0;
            end
        end
    end
endmodule
