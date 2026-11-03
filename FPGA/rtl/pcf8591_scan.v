`timescale 1ns/1ps
// Two instances run in parallel, each scans four single-ended inputs.
// 0x44: continuous internal oscillator, single-ended auto-increment from AIN0.
module pcf8591_scan #(
    parameter [6:0] ADDRESS=7'h48,
    parameter integer SCAN_CYCLES=36900,
    parameter integer QUARTER_CYCLES=62,
    parameter integer TIMEOUT_CYCLES=24600
) (
    input wire clk, rst_n,
    input wire [31:0] time_us,
    inout wire scl,sda,
    output reg [31:0] raw,
    output reg [3:0] raw_valid,
    output reg [127:0] sampled_at,
    output reg [15:0] scans, errors,
    output reg overdue
);
    reg [31:0] frame_count;
    reg [3:0] step;
    reg active, waiting, req;
    reg [2:0] op;
    reg [7:0] tx;
    reg ack;
    wire ready,done,error,nack;
    wire [7:0] rx;
    reg [31:0] conversion_start,result_start;
    i2c_byte_master #(.QUARTER_CYCLES(QUARTER_CYCLES),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)) bus (
        .clk(clk),.rst_n(rst_n),.req(req),.op(op),.tx_data(tx),
        .read_ack(ack),.ready(ready),.done(done),.error(error),.nack(nack),
        .rx_data(rx),.scl(scl),.sda(sda));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_count<=0; step<=0; active<=0; waiting<=0; req<=0;
            raw<=0; raw_valid<=0; sampled_at<=0; scans<=0; errors<=0;
            overdue<=0; conversion_start<=0; result_start<=0; op<=0;tx<=0;ack<=0;
        end else begin
            req<=0; raw_valid<=0;
            if (frame_count==SCAN_CYCLES-1) frame_count<=0;
            else frame_count<=frame_count+1;
            if (frame_count==0) begin
                if (!active) begin active<=1; step<=0; waiting<=0; end
                else overdue<=1;
            end
            if (active && !waiting && ready && !req) begin
                req<=1; waiting<=1; tx<=0; ack<=1;
                case (step)
                    0,3: op<=0;
                    1: begin op<=2; tx<={ADDRESS,1'b0}; end
                    2: begin op<=2; tx<=8'h44; end
                    4: begin op<=2; tx<={ADDRESS,1'b1}; end
                    5,6,7,8,9: begin op<=3; ack<=(step!=9); end
                    10: op<=1;
                    11: op<=4; // release stuck slave before next frame
                    default: op<=1;
                endcase
            end
            if (active && waiting && done) begin
                waiting<=0;
                if (step==11) active<=0;
                else if (error || nack) begin
                    if (errors!=16'hffff) errors<=errors+16'd1;
                    step<=11;
                end else if (step==10) begin
                    active<=0; scans<=scans+16'd1;
                end else begin
                    step<=step+4'd1;
                    // Address ACK starts AIN0 conversion. Every acknowledged
                    // result byte starts the next conversion while sending
                    // the previous result. Observe ACK via done one clock
                    // later, subtract 1 us to keep a conservative bound.
                    if (step==4) conversion_start<=time_us-32'd1;
                    if (step>=5 && step<=8) begin
                        result_start<=conversion_start;
                        conversion_start<=time_us-32'd1;
                    end
                    if (step>=6 && step<=9) begin
                        raw[(step-6)*8+:8]<=rx;
                        sampled_at[(step-6)*32+:32]<=result_start;
                        raw_valid[step-6]<=1;
                    end
                end
            end
        end
    end
endmodule
