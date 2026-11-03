`timescale 1ns/1ps
// Actual 115200 8N1 wire decoding, including changes during transmission.
module tb_oled_uart;
    reg clk=0; always #10 clk=~clk;
    reg rst=0,trigger=0,present=1;
    reg [1:0] mode=0;
    reg [10:0] keys=0;
    reg [7:0] touched=0,pressed=0;
    reg [63:0] raw=0;
    reg [15:0] seq=0;
    wire [1343:0] text;
    wire [1:0] screen_mode;
    wire [7:0] screen_keys;
    wire [15:0] screen_id,dropped;
    wire online,available,tx;
    tri1 scl,sda;
    reg slave_low=0,transaction=0;
    integer bus_bits=0;
    assign sda=slave_low ? 1'b0:1'bz;
    always @(negedge sda) if(scl===1'b1) begin transaction=1;bus_bits=0;end
    always @(posedge sda) if(scl===1'b1) transaction=0;
    always @(posedge scl) if(transaction) bus_bits=bus_bits+1;
    always @(negedge scl) if(transaction) begin
        if(bus_bits==8) slave_low=present;
        else if(bus_bits==9) begin slave_low=0;bus_bits=0;end
    end
    oled_status #(.POWERUP_MS(1),.HALF_CYCLES(4)) display(
        .clk(clk),.rst_n(rst),.octave(mode),.keys(keys),.history(112'd0),
        .history_valid(4'd0),.event_count(16'h1234),.scl(scl),.sda(sda),
        .screen_text(text),.screen_pitch(screen_mode),.screen_pressed(screen_keys),
        .screen_id(screen_id),.screen_online(online),.screen_available(available));
    telemetry_uart #(.CLOCK_HZ(50000000),.BAUD(115200),.OLED_DATA(1)) uart(
        .clk(clk),.rst_n(rst),.trigger(trigger),.time_us(32'd123456),.sequence_id(seq),
        .pressed(pressed),.seen(8'hff),.stale(8'd0),.flags(8'h82),.raw(raw),
        .sampled_at({8{32'd123400}}),.errors0(16'h12),.errors1(16'h34),
        .stolen(16'd0),.underruns(16'd0),.tx(tx),.dropped(dropped),
        .pitch_mode(mode),.touch_keys(touched),.screen_pitch(screen_mode),
        .screen_pressed(screen_keys),.screen_id(screen_id),.screen_online(online),
        .screen_available(available),.screen_text(text));
    reg [7:0] expected[0:239],value;
    integer i,sum,bitno,at=0,packets=0,file_handle,target;
    localparam real BIT_NS=1000000000.0/115200.0;
    initial begin
        file_handle=$fopen("oled_uart_fixture.bin","wb");
        forever begin
            @(negedge tx); #(BIT_NS/2); if(tx!==0) $fatal(1,"start");
            for(bitno=0;bitno<8;bitno=bitno+1) begin #(BIT_NS);value[bitno]=tx;end
            #(BIT_NS);if(tx!==1) $fatal(1,"stop");
            if(value!==expected[at]) $fatal(1,"UART packet=%0d offset=%0d got=%h expected=%h",packets,at,value,expected[at]);
            $fwrite(file_handle,"%c",value);
            if(at==239) begin packets=packets+1;at=0;end else at=at+1;
        end
    end
    task send;
        begin
            #1; // Allow published text combinational logic to settle after NBA.
            for(i=0;i<240;i=i+1) expected[i]=0;
            expected[0]=8'ha5;expected[1]=8'h5a;expected[2]=2;expected[3]=240;
            expected[4]=8'h40;expected[5]=8'he2;expected[6]=1;
            expected[8]=seq[7:0];expected[9]=seq[15:8];expected[10]=pressed;
            expected[11]=255;expected[13]=8'h82;
            for(i=0;i<8;i=i+1) begin
                expected[14+i]=raw[8*i +: 8];
                expected[22+4*i]=8'h08;expected[23+4*i]=8'he2;expected[24+4*i]=1;
            end
            expected[54]=8'h12;expected[56]=8'h34;
            expected[62]={6'd0,mode};expected[63]=touched;expected[64]={6'd0,screen_mode};
            expected[65]=screen_keys;expected[66]=10;expected[67]={6'd0,available,online};
            expected[68]=screen_id[7:0];expected[69]=screen_id[15:8];
            for(i=0;i<168;i=i+1) expected[70+i]=text[8*i +: 8];
            sum=0;for(i=0;i<238;i=i+1) sum=sum+expected[i];expected[238]=sum[7:0];expected[239]=sum[15:8];
            target=packets+1;
            @(negedge clk);trigger=1;@(negedge clk);trigger=0;
            repeat(500) @(negedge clk);
            // Live raw changes and a busy trigger cannot alter the held packet.
            raw=64'h0102030405060708;trigger=1;@(negedge clk);trigger=0;
            wait(packets==target);wait(!uart.active);seq=seq+1;
        end
    endtask
    initial begin
        #200;rst=1;
        send; // No completed OLED image yet; becomes available during this packet.
        mode=0;keys=1;pressed=1;touched=2;raw=64'd11;
        wait(available && screen_mode==0 && screen_keys==1);send;
        mode=1;keys=3;pressed=3;touched=1;raw=64'h0b0b;
        wait(screen_mode==1 && screen_keys==3);send;
        mode=2;keys=255;pressed=255;touched=4;raw={8{8'd128}};
        wait(screen_mode==2 && screen_keys==255);send;
        present=0;wait(!online);send;
        if(!available || dropped!==5) $fatal(1,"offline retention / busy drop");
        $fclose(file_handle);
        $display("PASS OLED UART: five 240-byte 115200 8N1 packets, checksum, exact metadata/text, snapshots immutable, LOW/MID/HIGH, NACK/offline cache, busy trigger drops");
        $finish;
    end
    initial begin #250000000; $fatal(1,"UART timeout");end
endmodule
