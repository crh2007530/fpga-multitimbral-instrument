`timescale 1ns/1ps
// V1:64 bytes; V2:240 bytes including a completed OLED text snapshot.
// Dropping a busy trigger never blocks pressure, OLED or audio.
module telemetry_uart #(parameter integer CLOCK_HZ=24600000,BAUD=921600,OLED_DATA=0)(
    input wire clk,rst_n,trigger,
    input wire [31:0] time_us,
    input wire [15:0] sequence_id,
    input wire [7:0] pressed,seen,stale,flags,
    input wire [63:0] raw,input wire [255:0] sampled_at,
    input wire [15:0] errors0,errors1,stolen,underruns,
    input wire [1:0] pitch_mode,screen_pitch,
    input wire [7:0] touch_keys,screen_pressed,
    input wire [15:0] screen_id,
    input wire screen_online,screen_available,
    input wire [1343:0] screen_text,
    output reg tx,output reg [15:0] dropped
);
    localparam integer FRAME_BYTES=OLED_DATA ? 240 : 64;
    reg [7:0] packet[0:FRAME_BYTES-1];
    reg [7:0] index;
    reg [3:0] bit_no;
    reg [9:0] shifter;
    reg [31:0] accumulator;
    reg active,sending;
    reg [15:0] checksum;
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx<=1;dropped<=0;index<=0;bit_no<=0;shifter<=1023;
            accumulator<=0;active<=0;sending<=0;checksum<=0;
            for(i=0;i<FRAME_BYTES;i=i+1) packet[i]<=0;
        end else begin
            if(trigger) begin
                if(active) begin if(dropped!=65535) dropped<=dropped+1;end
                else begin
                    packet[0]<=8'ha5;packet[1]<=8'h5a;
                    packet[2]<=OLED_DATA ? 2 : 1;packet[3]<=FRAME_BYTES;
                    for(i=0;i<4;i=i+1) packet[4+i]<=time_us[i*8+:8];
                    packet[8]<=sequence_id[7:0];packet[9]<=sequence_id[15:8];
                    packet[10]<=pressed;packet[11]<=seen;packet[12]<=stale;packet[13]<=flags;
                    for(i=0;i<8;i=i+1) packet[14+i]<=raw[i*8+:8];
                    for(i=0;i<32;i=i+1) packet[22+i]<=sampled_at[i*8+:8];
                    packet[54]<=errors0[7:0];packet[55]<=errors0[15:8];
                    packet[56]<=errors1[7:0];packet[57]<=errors1[15:8];
                    packet[58]<=stolen[7:0];packet[59]<=stolen[15:8];
                    packet[60]<=underruns[7:0];packet[61]<=underruns[15:8];
                    if(OLED_DATA) begin
                        packet[62]<={6'd0,pitch_mode};packet[63]<=touch_keys;
                        packet[64]<={6'd0,screen_pitch};packet[65]<=screen_pressed;
                        packet[66]<=8'd10;
                        packet[67]<={6'd0,screen_available,screen_online};
                        packet[68]<=screen_id[7:0];packet[69]<=screen_id[15:8];
                        for(i=0;i<168;i=i+1) packet[70+i]<=screen_text[i*8 +: 8];
                    end
                    index<=0;active<=1;sending<=0;accumulator<=0;checksum<=0;
                end
            end
            if(active && !sending) begin
                // Accumulate over transmitted payload bytes, avoiding a wide
                // combinational sum. The snapshot remains stable while busy.
                if(index<FRAME_BYTES-2) begin
                    checksum<=checksum+{8'd0,packet[index]};
                    shifter<={1'b1,packet[index],1'b0};
                end else if(index==FRAME_BYTES-2) shifter<={1'b1,checksum[7:0],1'b0};
                else shifter<={1'b1,checksum[15:8],1'b0};
                tx<=0;
                bit_no<=0;accumulator<=0;sending<=1;
            end else if(sending) begin
                if(accumulator>=CLOCK_HZ-BAUD) begin
                    accumulator<=accumulator+BAUD-CLOCK_HZ;
                    if(bit_no==9) begin
                        sending<=0;tx<=1;
                        if(index==FRAME_BYTES-1) active<=0;else index<=index+1;
                    end else begin shifter<={1'b1,shifter[9:1]};tx<=shifter[1];bit_no<=bit_no+1;end
                end else accumulator<=accumulator+BAUD;
            end
        end
    end
endmodule
