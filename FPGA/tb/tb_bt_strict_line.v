`timescale 1ns/1ps
module tb_bt_strict_line;
reg clk=0;always #10 clk=~clk;reg rst=0,rx=1;
wire tx,kv,toggle,vv;wire[7:0]km;wire[5:0]fx;wire[1:0]vs;
bluetooth_control #(.CLOCK_HZ(320000),.BAUD(10000)) dut(
 .clk(clk),.rst_n(rst),.rx(rx),.test_mode(1'b0),.trainer_active(1'b0),.trainer_running(1'b0),.trainer_done(1'b0),
 .tx(tx),.key_valid(kv),.key_mask(km),.trainer_toggle(toggle),.effect_events(fx),.visual_valid(vv),.visual_select(vs));
integer actions=0;always @(posedge clk)if(kv || toggle || vv || |fx)actions=actions+1;
task send_byte;input[7:0]v;integer j;begin
 @(negedge clk);rx=0;repeat(32)@(negedge clk);
 for(j=0;j<8;j=j+1)begin rx=v[j];repeat(32)@(negedge clk);end
 rx=1;repeat(32)@(negedge clk);
end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;
 send_byte("z");send_byte("@");send_byte("T");send_byte(10);repeat(400)@(negedge clk);
 if(actions!=0)$fatal(1,"Malformed line z@T executed despite exact-line protocol");
 send_byte("@");send_byte("T");send_byte(10);repeat(400)@(negedge clk);
 if(actions!=1)$fatal(1,"valid line after malformed line lost");
 $display("PASS exact-line parser rejects embedded command after junk, recovers on newline");$finish;
end
endmodule
