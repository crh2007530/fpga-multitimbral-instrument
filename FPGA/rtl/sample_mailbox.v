`timescale 1ns/1ps
// Bundled-data request/acknowledge crossing. The payload remains stable until
// the destination has acknowledged it. New ADC samples arrive every ~1.5 ms;
// a normal crossing/acknowledge takes only a few source/destination clocks.
module sample_mailbox #(parameter integer WIDTH=8)(input wire src_clk,src_rst_n,input wire src_valid,
    input wire [WIDTH-1:0] src_data,input wire dst_clk,dst_rst_n,
    output reg dst_valid,output reg [WIDTH-1:0] dst_data);
    reg [WIDTH-1:0] payload;
    reg request,acknowledge;
    reg [1:0] ack_sync,req_sync;
    always @(posedge src_clk or negedge src_rst_n) begin
        if(!src_rst_n) begin payload<=0;request<=0;ack_sync<=0;end
        else begin
            ack_sync<={ack_sync[0],acknowledge};
            if(src_valid && request==ack_sync[1]) begin payload<=src_data;request<=~request;end
        end
    end
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if(!dst_rst_n) begin req_sync<=0;acknowledge<=0;dst_valid<=0;dst_data<=0;end
        else begin
            req_sync<={req_sync[0],request};dst_valid<=0;
            if(req_sync[1]!=acknowledge) begin
                dst_data<=payload;dst_valid<=1;acknowledge<=req_sync[1];
            end
        end
    end
endmodule
