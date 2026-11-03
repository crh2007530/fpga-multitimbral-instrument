`timescale 1ns/1ps
`include "tb/joint07_uart_reference.v"
module tb_v30_logger_stress;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,trigger=0;reg [31:0] time_us=0;reg [15:0] seq=0;
 reg [5:0] events=0;wire tx;
 always @(posedge clk)if(rst)time_us<=time_us+1;
 joint07_uart #(.CLOCK_HZ(1000),.BAUD(100),.EXTENDED(1),.TOUCH_DIAG(1),.EXPANSION(1),.HEALTH(1)) dut(.audio_underruns(16'h1234),.spectrum_frames(32'h89abcdef),.spectrum_missed(32'h76543210),
 .clk(clk),.rst_n(rst),.trigger(trigger),.time_us(time_us),.sequence_id(seq),
 .pressed(8'hc3),.seen(8'hff),.stale(8'h00),.flags(8'h82),
 .raw(64'h8070605040302010),.sampled_at(256'd0),.errors0(16'd2),.errors1(16'd3),
 .pitch_mode(2'd1),.touch_keys(8'd1),.events(events),.apds_ready(1'b1),
 .prox_valid(1'b1),.prox(8'd128),.apds_errors(32'd7),.recoveries(32'd2),.tx(tx),
 .touch_scans(32'h12345678),.touch_full(16'habcd),.command_count(16'h1234),.last_command(8'h08),.touch_sdo(1'b1),
 .chord_mode(1'b1),.test32(1'b1),.selected_test(6'd63),.mask32(64'h7ffffffe12345678),
 .voice_modes(16'h4926),.selected(4'd2),.test_mode(1'b1),.test_mask(4'hb));

 wire reference_tx;
 joint07_uart_reference #(.CLOCK_HZ(1000),.BAUD(100),.EXTENDED(1),.TOUCH_DIAG(1),.EXPANSION(1),.HEALTH(1)) reference(.audio_underruns(16'h1234),.spectrum_frames(32'h89abcdef),.spectrum_missed(32'h76543210),
 .clk(clk),.rst_n(rst),.trigger(trigger),.time_us(time_us),.sequence_id(seq),
 .pressed(8'hc3),.seen(8'hff),.stale(8'h00),.flags(8'h82),
 .raw(64'h8070605040302010),.sampled_at(256'd0),.errors0(16'd2),.errors1(16'd3),
 .pitch_mode(2'd1),.touch_keys(8'd1),.events(events),.apds_ready(1'b1),
 .prox_valid(1'b1),.prox(8'd128),.apds_errors(32'd7),.recoveries(32'd2),.tx(reference_tx),
 .touch_scans(32'h12345678),.touch_full(16'habcd),.command_count(16'h1234),.last_command(8'h08),.touch_sdo(1'b1),
 .chord_mode(1'b1),.test32(1'b1),.selected_test(6'd63),.mask32(64'h7ffffffe12345678),
 .voice_modes(16'h4926),.selected(4'd2),.test_mode(1'b1),.test_mask(4'hb));
 always @(negedge clk)if(rst && tx!==reference_tx)$fatal(1,"UART wire changed");

integer fill,n;reg[8:0]takes=0;
always @(posedge clk)if(rst && dut.snapshot)takes[dut.take]=1;
initial begin
for(fill=0;fill<=32;fill=fill+1)begin
 @(negedge clk);rst=0;trigger=0;events=0;repeat(3)@(negedge clk);rst=1;repeat(4)@(negedge clk);
 for(n=0;n<fill;n=n+1)begin events=1 << (n%6);@(negedge clk);end
 events=3;trigger=1;@(negedge clk);trigger=0;
 repeat(12)begin events=events+1;@(negedge clk);end
 events=0;wait(!dut.active);repeat(3)@(negedge clk);
end
if(takes!==9'h1ff)$fatal(1,"take coverage");
$display("PASS 33 bit-identical UART frames, all occupancies 0..32, take0..8, simultaneous push/dequeue and freed-slot overwrite boundary");$finish;
end
endmodule
