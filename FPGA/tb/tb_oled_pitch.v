`timescale 1ns/1ps
// Decode actual I2C bytes and compare the complete 128x64 screen.
module tb_oled_pitch;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0;
    reg [1:0] mode=0;
    reg [10:0] keys=0;
    reg [111:0] history=0;
    reg [3:0] valid=0;
    reg [15:0] count=0;
    tri1 scl,sda;
    reg slave_low=0;
    assign sda=slave_low ? 1'b0 : 1'bz;
    oled_status #(.POWERUP_MS(1),.HALF_CYCLES(4)) dut(
        .clk(clk),.rst_n(rst_n),.octave(mode),.keys(keys),
        .history(history),.history_valid(valid),.event_count(count),.scl(scl),.sda(sda));
    reg [167:0] lines[0:7];
    reg [7:0] value,expected_char,expected_pixel;
    reg [39:0] glyph;
    integer bitno,p,x,col;
    integer published_id=0,k;
    task start;
        begin @(negedge sda); while(scl!==1'b1) @(negedge sda); end
    endtask
    task receive;
        begin
            for(bitno=7;bitno>=0;bitno=bitno-1) begin
                @(posedge scl); value[bitno]=sda;
            end
            @(negedge scl); slave_low=1;
            @(posedge scl); @(negedge scl); slave_low=0;
        end
    endtask
    task prefix;
        input [7:0] control;
        begin
            start; receive;
            if(value!==8'h78) $fatal(1,"OLED address %h",value);
            receive;
            if(value!==control) $fatal(1,"OLED control %h",value);
        end
    endtask
    task frame;
        input change_midframe;
        begin
            for(p=0;p<8;p=p+1) begin
                prefix(0);
                receive; if(value!==(8'hb0+p)) $fatal(1,"page command");
                receive; if(value!==0) $fatal(1,"low column");
                receive; if(value!==8'h10) $fatal(1,"high column");
                prefix(8'h40);
                for(x=0;x<128;x=x+1) begin
                    receive;
                    col=x%6;
                    expected_char=(x/6<21) ? lines[p][167-8*(x/6) -: 8] : 8'h20;
                    glyph=dut.font(expected_char);
                    expected_pixel=(col<5) ? glyph[8*col +: 8] : 0;
                    if(value!==expected_pixel)
                        $fatal(1,"pixels page=%0d x=%0d got=%h expected=%h char=%c",p,x,value,expected_pixel,expected_char);
                end
                if(p==0 && change_midframe) begin mode=2; keys=1; end
            end
            wait(dut.screen_id!=published_id);#1;published_id=dut.screen_id;
            for(k=0;k<168;k=k+1) begin
                expected_char=lines[k/21][167-8*(k%21) -: 8];
                if(dut.screen_text[8*k +: 8]!==expected_char) $fatal(1,"published text differs from ACKed OLED at %0d",k);
            end
        end
    endtask
    initial begin
        lines[0]="MID C5  523.25HZ     ";
        lines[1]="KEYS: -------- E:0000";
        lines[2]="TTP 1=LOW 2=MID      ";
        lines[3]="3=HIGH RAW>10=ON     ";
        for(p=4;p<8;p=p+1) lines[p]="                     ";
        #100; rst_n=1;
        prefix(0); repeat(25) receive;
        frame(1); // Inputs change during page 0, but every page keeps its snapshot.
        lines[0]="HIGH C6 1046.50HZ    ";
        lines[1]="KEYS: 1------- E:0000";
        lines[4]="Z1 C6 ON             ";
        frame(0);
        mode=1; keys=3; count=16'h0003; valid=7;
        history={28'd0,16'h0001,4'd1,1'b1,7'd72,
            16'h0002,4'd2,1'b1,7'd74,16'h0003,4'd1,1'b0,7'd60};
        lines[0]="LOW C4  261.63HZ     ";
        lines[1]="KEYS: 12------ E:0003";
        lines[4]="Z1 C4 ON   Z2 D4 ON  ";
        frame(0);
        keys=0; // Touch release retains the selected pitch.
        lines[1]="KEYS: -------- E:0003";
        lines[4]="                     ";
        frame(0);
        keys=255;
        lines[1]="KEYS: 12345678 E:0003";
        lines[4]="Z1 C4 ON   Z2 D4 ON  ";
        lines[5]="Z3 E4 ON   Z4 F4 ON  ";
        lines[6]="Z5 G4 ON   Z6 A4 ON  ";
        lines[7]="Z7 B4 ON   Z8 C5 ON  ";
        frame(0);
        mode=2;
        lines[0]="HIGH C6 1046.50HZ    ";
        lines[4]="Z1 C6 ON   Z2 D6 ON  ";
        lines[5]="Z3 E6 ON   Z4 F6 ON  ";
        lines[6]="Z5 G6 ON   Z6 A6 ON  ";
        lines[7]="Z7 B6 ON   Z8 C7 ON  ";
        frame(0);
        $display("PASS OLED: LOW/MID/HIGH, all live zones, idle has no Z labels, old history hidden, frame snapshot, all pixels");
        $finish;
    end
    initial begin #150000000; $fatal(1,"OLED timeout"); end
endmodule

