`timescale 1ns/1ps
module tb_instrument_mixer;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,blocked=0,open=0,nxt=0,prev=0,inc=0,dec=0,remote=0,echo=0,clear=0;
 reg[2:0]base=0;reg[1:0]inst=0;
 wire active;wire[3:0]item;wire[32:0]cfg;wire[2:0]en,edited;wire[1:0]ep,cp,current;
 instrument_mixer_controls dut(clk,rst,blocked,open,nxt,prev,inc,dec,base,active,item,cfg,en,ep,cp,edited,remote,echo,clear,inst,current);
 wire[42:0]state={cfg,en,ep,cp,edited};reg[42:0]saved[0:2];integer i,j,k;
 task tick;begin @(negedge clk);end endtask
 task select_item;input[3:0]which;begin while(item!=which)begin nxt=1;tick();nxt=0;tick();end end endtask
 task up;begin inc=1;tick();inc=0;tick();end endtask
 task switch;input[1:0]n;begin inst=n;repeat(3)tick();if(current!=n)$fatal(1,"wrong instrument identity");end endtask
 initial begin
 repeat(3)tick();rst=1;tick();open=1;tick();open=0;tick();
 if(!active || item!=15)$fatal(1,"instrument selector missing");
 for(i=0;i<3;i=i+1)begin
  switch(i);select_item(0);up();select_item(1);for(j=0;j<=i;j=j+1)up();
  select_item(2);for(j=0;j<i;j=j+1)up();
  select_item(5);for(j=0;j<=i;j=j+1)up();
  select_item(10);for(j=0;j<i;j=j+1)up();
  select_item(14);dec=1;for(j=0;j<i+1;j=j+1)tick();dec=0;tick();
  saved[i]=state;
 end
 for(k=0;k<300;k=k+1)begin i=k%3;switch(i);if(state!==saved[i])$fatal(1,"preset leaked bank=%0d",i);end
 // Explicit app OFF overrides stored panel enable only in the current bank.
 switch(1);base=0;remote=1;tick();remote=0;tick();
 if(en[0] || en[2])$fatal(1,"app OFF ignored");saved[1]=state;
 switch(0);if(state!==saved[0])$fatal(1,"app command leaked to other instrument");
 switch(1);if(state!==saved[1])$fatal(1,"app state not retained");
 echo=1;tick();echo=0;tick();saved[1]=state;switch(2);switch(1);
 if(state!==saved[1])$fatal(1,"gesture echo state not retained");
 blocked=1;tick();if(active)$fatal(1,"blocked page stayed active");blocked=0;
 rst=0;tick();rst=1;tick();inst=0;repeat(3)tick();
 if(cfg!==dut.DEFAULT_CONFIG || en!=0)$fatal(1,"reset defaults failed");
 $display("PASS instrument mixer: 3 independent complete FX/dry states,300 switches,selector navigation,app override,gesture echo,blocked modes,reset");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
