`timescale 1ns/1ps
module tb_poly8_top;
    reg clk=0;always #10 clk=~clk;
    tri1 scl0,sda0,scl1,sda1;
    reg present0=1,present1=1,lost0=0,lost1=0;
    reg [31:0] codes0=0,codes1=0;
    wire [31:0] transactions0,transactions1;
    pcf8591_model adc0(scl0,sda0,present0,codes0,transactions0);
    pcf8591_model adc1(scl1,sda1,present1,codes1,transactions1);
    wire bclk,lrclk,din,xsmt,tx,led;
    wire bclk2,lrclk2,din2,xsmt2,dout;
    tri1 oled_scl,oled_sda;
    pressure_poly8_top #(.OLED_TELEMETRY(0)) dut(.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.clk_50m(clk),.adc0_scl(scl0),.adc0_sda(sda0),
        .adc1_scl(scl1),.adc1_sda(sda1),.i2s_bclk(bclk),.i2s_lrclk(lrclk),
        .i2s_din(din),.xsmt(xsmt),.debug_tx(tx),.status_led(led),
        .pcm2_bclk(bclk2),.pcm2_lrclk(lrclk2),.pcm2_din(din2),.pcm2_xsmt(xsmt2),
        .dout(dout),.oled_scl(oled_scl),.oled_sda(oled_sda),.ttp_scl(),.ttp_sdo(1'b1));
    wire [719:0] strip_pixels;
    wire [31:0] strip_frames;
    ws2812_monitor monitor(dout,strip_pixels,strip_frames);
    always @(posedge clk) begin
        #1;
        if({bclk2,lrclk2,din2,xsmt2}!=={bclk,lrclk,din,xsmt})
            $fatal(1,"PCM2 differs from PCM1");
    end
    task check_strip;
        input [63:0] expected_raw;
        integer led,region;
        reg [7:0] b;
        reg [23:0] expected;
        begin
            if(strip_frames==0) $fatal(1,"No physical WS2812 frame");
            for(led=0;led<30;led=led+1) begin
                region=led/3;expected=0;b=0;
                if(region<8) begin
                    b=expected_raw[region*8+:8];if(b<=10) b=0;
                    case(region)
                        0:expected={8'd0,b,8'd0};1:expected={b,8'd0,8'd0};
                        2:expected={8'd0,8'd0,b};3:expected={b,b,8'd0};
                        4:expected={b,8'd0,b};5:expected={8'd0,b,b};
                        6,7:expected={b,b,b};
                    endcase
                end
                if(strip_pixels[led*24+:24]!==expected)
                    $fatal(1,"ADC->physical strip region mismatch LED%0d got%h expected%h",led,strip_pixels[led*24+:24],expected);
            end
        end
    endtask
    reg [7:0] packet[0:63];reg [7:0] value;
    integer byte_index=0,bit_index,checksum,packets=0,all_pressed=0,stale0_packets=0,stale1_packets=0;
    integer crossings[0:7];integer ch;
    localparam real BIT_NS=1000000000.0/115200.0;
    initial begin
        for(ch=0;ch<8;ch=ch+1) crossings[ch]=0;
        forever begin
            @(negedge tx);#(BIT_NS/2);if(tx!==0) $fatal(1,"UART start");
            for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin #(BIT_NS);value[bit_index]=tx;end
            #(BIT_NS);if(tx!==1) $fatal(1,"UART stop");
            packet[byte_index]=value;
            if(byte_index==63) begin
                if(packet[0]!=8'ha5 || packet[1]!=8'h5a || packet[2]!=1 || packet[3]!=64) $fatal(1,"Header");
                checksum=0;for(bit_index=0;bit_index<62;bit_index=bit_index+1) checksum=checksum+packet[bit_index];
                if({packet[63],packet[62]}!=checksum) $fatal(1,"Checksum");
                if(packet[13][7:4]!=8 || packet[11]!=8'hff) $fatal(1,"Eight-channel telemetry");
                if(!lost0 && {packet[55],packet[54]}!=0) $fatal(1,"Unexpected ADC0 errors");
                if(!lost1 && {packet[57],packet[56]}!=0) $fatal(1,"Unexpected ADC1 errors");
                if(packet[10]==255) all_pressed=all_pressed+1;
                if(packet[12][3:0]==15) stale0_packets=stale0_packets+1;
                if(packet[12][7:4]==15) stale1_packets=stale1_packets+1;
                packets=packets+1;byte_index=0;
            end else byte_index=byte_index+1;
        end
    end
    genvar g;
    generate for(g=0;g<8;g=g+1) begin: observe
        always @(posedge dut.audio_clk) if(dut.audio_valid[g]) begin
            if(dut.audio_raw[g*8+:8]==8'hee) $fatal(1,"Dummy byte reached note %0d",g);
            crossings[g]=crossings[g]+1;
        end
    end endgenerate
    initial begin
        #24000000;
        if(dut.held_audio!=0 || !xsmt) $fatal(1,"Startup");
        check_strip(0);
        codes0=32'h80706050;codes1=32'hc0b0a090;#22000000;
        if(dut.held_audio!==255 || dut.audio_raw!=={codes1,codes0}) $fatal(1,"Eight mailbox payload/press");
        check_strip({codes1,codes0});
        codes1[7:0]=0;#4000000;if(dut.held_audio!==8'hef) $fatal(1,"Release pad5");
        codes1[7:0]=144;#4000000;
        @(posedge transactions0);#10000;lost0=1;present0=0;#30000000;
        if(dut.held_audio!==8'hf0 || dut.errors0==0 || dut.errors1!=0) $fatal(1,"ADC0 loss isolation");
        check_strip({codes1,32'd0});
        // Restore ADC0 while ADC1 remains active, then lose ADC1 alone.
        present0=1;#4000000;
        if(dut.held_audio!==255) $fatal(1,"ADC0 reconnection");
        #2000000;check_strip({codes1,codes0});
        @(posedge transactions1);#10000;lost1=1;present1=0;#30000000;
        if(dut.held_audio!==8'h0f || dut.errors1==0) $fatal(1,"ADC1 loss isolation");
        check_strip({32'd0,codes0});
        codes0=0;#8000000;
        if(dut.held_audio!=0 || dut.underruns!=0 || all_pressed==0 || stale0_packets==0 || stale1_packets==0 || packets<5) $fatal(1,"Coverage/release");
        for(ch=0;ch<8;ch=ch+1) if(crossings[ch]<10) $fatal(1,"Missing CDC coverage %0d",ch);
        $display("PASS INTEGRATION (dual PCM mirror and wire-decoded WS2812): two wire-level ADCs, eight CDC payloads, eight-bit UART pressed mask/checksum, pad5 release, independent ADC0/ADC1 loss and ADC0 recovery; packets=%0d",packets);
        $finish;
    end
    initial begin #250000000;$fatal(1,"Timeout");end
endmodule

