`timescale 1ns/1ps
// Decode actual output pulses, independent of DUT counters and frame buffer.
module ws2812_monitor(input wire dout, output reg [719:0] pixels=0,
    output integer frames=0);
    reg [719:0] pending=0;
    reg [23:0] word_data=0;
    integer bits=0, width_ns;
    time rise_at=0, last_fall=0, previous_rise=0;
    reg have_rise=0;
    always @(posedge dout) begin
        if (!have_rise || $time-last_fall>50000) begin
            if (bits!=0 && bits!=720) $fatal(1,"Truncated WS2812 frame: %0d bits",bits);
            if (frames>0 && $time-last_fall<280000) $fatal(1,"WS2812 reset too short");
            bits=0;word_data=0;
        end else if ($time-previous_rise!=1240) $fatal(1,"WS2812 bit period");
        rise_at=$time;previous_rise=$time;have_rise=1;
    end
    always @(negedge dout) if(have_rise) begin
        width_ns=$time-rise_at;
        if(width_ns!=400 && width_ns!=800) $fatal(1,"WS2812 high time %0d",width_ns);
        word_data={word_data[22:0],(width_ns==800)};
        if(bits>=720) $fatal(1,"Too many WS2812 bits");
        if(bits%24==23) pending[(bits/24)*24+:24]=word_data;
        bits=bits+1;last_fall=$time;
        if(bits==720) begin pixels=pending;frames=frames+1;end
    end
endmodule
