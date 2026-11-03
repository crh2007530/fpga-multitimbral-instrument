`timescale 1ns/1ps
module tb_control_chain;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,rx=1;wire tx,kv,toggle,vv,lock,active,running,done,exit_game,test_mode;
 wire[7:0] km,xd,rd;wire[5:0] fx;wire[1:0]vs,extra_fx;
 wire xv,xready,xb,rv,re;wire[255:0] chart;wire[55:0] map;wire ce,me;
 bluetooth_control #(.CLOCK_HZ(320000),.BAUD(10000),.FEATURES(1)) bt(
 .clk(clk),.rst_n(rst),.rx(rx),.test_mode(test_mode),.trainer_active(active),.trainer_running(running),.trainer_done(done),
 .tx(tx),.key_valid(kv),.key_mask(km),.trainer_toggle(toggle),.effect_events(fx),.visual_valid(vv),.visual_select(vs),.control_lock(lock),
 .ext_tx_valid(xv),.ext_tx_data(xd),.ext_busy(xb),.ext_tx_ready(xready),.rx_data_out(rd),.rx_valid_out(rv),.rx_error_out(re));
 bt_extensions #(.CLOCK_HZ(320000),.CLIP_ADDR_BITS(5)) ext(clk,rst,rd,rv,re,xv,xd,xready,xb,active,8'd0,1'b0,16'd0,ce,chart,me,map,extra_fx,,,,,);
 rhythm_game #(.CUSTOM_CHART(1)) game(.clk(clk),.rst_n(rst),.frame_valid(1'b0),.keys(8'd0),.pressed(8'd0),.test_mode(test_mode),
 .remote_valid(kv),.remote_keys(km),.remote_toggle(toggle),.local_inhibit(1'b0),.user_chart(chart),.chart_enabled(ce),
 .active(active),.running(running),.done(done),.exit_pulse(exit_game));
 performance_controls #(.EXPANSION(1),.EXTERNAL_CLEAR(1),.REMOTE(1)) perf(.clk(clk),.rst_n(rst),.frame_valid(1'b0),.keys(8'd0),
 .clear(exit_game),.remote_valid(kv&&!active),.remote_keys(km),.test_mode(test_mode));
 wire[7:0] reply;wire reply_valid,reply_error;
 bt_uart_rx #(.CLOCK_HZ(320000),.BAUD(10000)) monitor(clk,rst,tx,reply,reply_valid,reply_error);
 reg[7:0] replies[0:255];integer count=0,fd;
 always @(posedge clk)if(reply_valid)begin replies[count]=reply;count=count+1;$fwrite(fd,"%c",reply);end
 task byte_send;input[7:0] b;integer j;begin
 @(negedge clk);rx=0;repeat(32)@(negedge clk);for(j=0;j<8;j=j+1)begin rx=b[j];repeat(32)@(negedge clk);end
 rx=1;repeat(32)@(negedge clk);end endtask
 task command;input[7:0] c,expected;integer before_count;begin
 before_count=count;byte_send("@");byte_send(c);byte_send(10);repeat(400)@(negedge clk);
 if(count!=before_count+1||replies[count-1]!=expected)$fatal(1,"command %c expected %c",c,expected);
 end endtask
 integer i;
 initial begin fd=$fopen("checks/control_chain_uart.txt","w");repeat(5)@(negedge clk);rst=1;
 command("?","N");command("T","K");command("?","P");if(!active||running)$fatal(1,"entry");
 for(i=0;i<10;i=i+1)begin
 command("5","K");command("?","R");if(!running)$fatal(1,"start/resume");
 command("5","K");command("?","P");if(running)$fatal(1,"pause");
 end
 // Software exact F packet: both effects; real UART + extension arbitration.
 byte_send("!");byte_send("F");byte_send("0");byte_send("1");byte_send("0");byte_send("1");byte_send("0");byte_send("3");byte_send("B");byte_send("5");byte_send(10);
 repeat(5000)@(negedge clk);if(extra_fx!=3)$fatal(1,"F apply");
 command("?","P");command("5","K");command("?","R");
 command("8","K");command("?","N");if(active||test_mode)$fatal(1,"exit");
 // Old Android compatible and no double response/action on CRLF.
 byte_send("@");byte_send("T");byte_send(13);byte_send(10);repeat(400)@(negedge clk);
 command("?","P");command("8","K");command("?","N");
 $fclose(fd);$display("PASS actual UART + extension parser + performance + rhythm: 10 pause/resume cycles, mode readback, FX set, exit, CRLF");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
