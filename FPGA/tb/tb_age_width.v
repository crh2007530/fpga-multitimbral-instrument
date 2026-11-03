`timescale 1ns/1ps
module tb_age_width;
 reg clk=0;always #5 clk=~clk;reg rst=0,pv=0,ce=0;reg[7:0] raw=0;
 wire h0,h1,e0,e1;integer n;reg[31:0] rng=32'h938ac217;
 pressure_voice_state dut(.clk(clk),.rst_n(rst),.sample_ce(ce),.pressure_valid(pv),.pressure_raw(raw),.phase_inc(32'd1234567),.held(h0),.envelope_active(e0));
 pcm_pressure_note reference(.clk(clk),.rst_n(rst),.sample_ce(ce),.pressure_valid(pv),.pressure_raw(raw),.runtime_inc(32'd1234567),.sine_mode(1'b0),.held(h1),.envelope_active(e1));
 always @(posedge clk)begin #1;if(rst)begin
  if({h0,e0,dut.age,dut.force_hold,dut.envelope} !== {h1,e1,reference.age[17:0],reference.force_hold,reference.envelope})$fatal(1,"state mismatch cycle %d",n);
 end end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(n=0;n<800000;n=n+1)begin
   @(negedge clk);ce=n%512==0;rng=(rng<<1)^(rng[31]?32'h04c11db7:0);
   pv=n<10000 ? n%37==0 : n==270000 || n==540000;
   raw=n<10000 ? rng[7:0] : 8'd100;
  end
  if(dut.age!=246000 || h0)$fatal(1,"stale saturation");
  $display("PASS 800000-cycle age-width equivalence: random pressures, three 10ms stale windows, saturation, envelope and force state");$finish;
 end
endmodule
