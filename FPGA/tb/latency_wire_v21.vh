`timescale 1ns/1ps
// Exact production ADC-valid boundary -> 8 mailboxes -> audio core -> physical I2S pins.
// External ADC scan, sensor and DAC analogue delay are outside this harness.
module latency_wire_v21 #(parameter LOAD=0,TIMBRE=0);
reg sc=0,ac=0;always #10 sc=~sc;always #20.325 ac=~ac;
reg rst=0;reg[7:0] iv=0;reg[63:0] raw=0;wire[7:0] av;wire[63:0] ar;
genvar g;generate for(g=0;g<8;g=g+1)begin:crossings
 sample_mailbox mb(sc,rst,iv[g],raw[g*8+:8],ac,rst,av[g],ar[g*8+:8]);
end endgenerate
wire ct,mv,bclk,lrclk,din,xsmt;wire signed[15:0] pcm;wire[15:0] under;wire[63:0] held;
pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.CUSTOM_MAP(1),.MULTIFX(1),.THIRD_TIMBRE(1),.USER_ADSR(1),.MASTER_VOLUME(1)) dut(.master_volume(5'd16),.epiano_mode(TIMBRE==2),.adsr_config(61'd0),
 .clk(ac),.rst_n(rst),.pressure_valid(av),.pressure_raw(ar),.voice_modes(16'd0),.chord_mode(LOAD!=0),
 .test_mode(1'b0),.test32(1'b0),.test_mask(4'hf),.mask32(~64'd0),.expression_config({LOAD!=0,LOAD!=0,LOAD!=0,TIMBRE==1}),
 .map_enabled(1'b1),.keymap({7'd72,7'd71,7'd69,7'd67,7'd65,7'd64,7'd62,7'd60}),.extra_fx(LOAD?2'd3:2'd0),
 .control_tick(ct),.monitor_valid(mv),.monitor_pcm(pcm),.held32(held),.bclk(bclk),.lrclk(lrclk),.din(din),.xsmt(xsmt),.underruns(under));
wire[1023:0] observed_forces=dut.shared_forces;
integer n;
integer phase,i,fd,seq=0,admit_cycle,cycle=0,snapshot_cycle,mon_cycle,frame_cycle;
integer min_c=99999,max_c=-1,min_m=99999,max_m=-1,nonzero=0;
realtime t0,tc,ta,ts,tm,tf,tfirst,tlast,tright,min_ns=1.0e12,max_ns=0;
reg armed=0;reg[7:0] value;reg[15:0] expected,word,left_word;
always @(posedge sc)if(armed && iv[0])t0=$realtime;
always @(posedge ac)begin
 cycle=cycle+1;
 if(armed)begin
  if(av[0] && ar[7:0]==value)tc=$realtime;
  if(dut.scheduled_valid[0] && dut.scheduled_raw[7:0]==value)begin ta=$realtime;admit_cycle=cycle;end
  if(ta>=0 && ts<0 && dut.shared_forces[15:0]=={1'b0,value,7'b0})begin ts=$realtime;snapshot_cycle=cycle;end
  if(ts>=0 && tm<0 && mv)begin
   tm=$realtime;mon_cycle=cycle;expected=pcm;
   for(n=0;n<64;n=n+1)if((LOAD!=0 || n==0) && observed_forces[n*16+:16]!=={1'b0,value,7'b0})$fatal(1,"force snapshot mismatch voice %0d",n);
  end
 end
end
initial begin
 fd=$fopen(LOAD?"checks/latency_v21_full64.csv":"checks/latency_v21_single.csv","w");
 $fwrite(fd,"phase,src_ns,cdc_ns,admit_ns,operand_ns,pcm_ns,frame_ns,msb_ns,left_complete_ns,right_complete_ns,pcm_value\n");
 repeat(8)@(negedge sc);rst=1;
 wait(xsmt);repeat(1024)@(negedge ac);
 for(phase=0;phase<512;phase=phase+1)begin
  wait(ct);@(posedge ac);@(negedge ac);repeat(phase)@(negedge ac);
  @(negedge sc);value=phase[0]?8'd160:8'd96;raw=LOAD?{8{value}}:{56'd0,value};
  t0=-1;tc=-1;ta=-1;ts=-1;tm=-1;armed=1;iv=8'hff;
  @(negedge sc);iv=0;
  wait(tm>=0);@(negedge lrclk);#0.001;tf=$realtime;frame_cycle=cycle;
  if(dut.tx.frame_sample!==expected)$fatal(1,"PCM missed next I2S frame phase=%0d",phase);
  if(frame_cycle-admit_cycle!=104)$fatal(1,"admission->frame variable %0d",frame_cycle-admit_cycle);
  @(posedge bclk); // I2S one-bit dummy at bit 0
  word=0;
  for(i=0;i<16;i=i+1)begin @(posedge bclk);word={word[14:0],din};if(i==0)tfirst=$realtime;end
  tlast=$realtime;left_word=word;
  if(word!==expected)$fatal(1,"left I2S sample mismatch");
  repeat(16)@(posedge bclk); // padding + right one-bit dummy
  word=0;repeat(16)begin @(posedge bclk);word={word[14:0],din};end
  tright=$realtime;if(word!==expected)$fatal(1,"right I2S mismatch");
  if(tc<t0 || ta<tc || ts<ta || tm<ts || tf<tm)$fatal(1,"stage ordering");
  if((tlast-ta)<9593.3 || (tlast-ta)>9593.5)$fatal(1,"left output schedule differs %f",tlast-ta);
  if(tlast-t0>32000.0)$fatal(1,"received input->left sample over 32us");
  if(tlast-t0<min_ns)min_ns=tlast-t0;if(tlast-t0>max_ns)max_ns=tlast-t0;
  if(mon_cycle-admit_cycle<min_m)min_m=mon_cycle-admit_cycle;if(mon_cycle-admit_cycle>max_m)max_m=mon_cycle-admit_cycle;
  if(left_word!=0)nonzero=nonzero+1;
  if(LOAD && held!==~64'd0)$fatal(1,"not all64 active");
  if(under!=0)$fatal(1,"underrun");
  $fwrite(fd,"%0d,%0.3f,%0.3f,%0.3f,%0.3f,%0.3f,%0.3f,%0.3f,%0.3f,%0.3f,%0d\n",phase,t0,tc,ta,ts,tm,tf,tfirst,tlast,tright,$signed(expected));
  armed=0;seq=seq+1;
  if(phase%64==63)$display("progress load=%0d phase=%0d",LOAD,phase);
 end
 $fclose(fd);
 if(seq!=512 || min_m!=max_m)$fatal(1,"coverage or variable processing latency");
 $display("PASS load=%0d all512 launch offsets; source-valid->left-complete min=%0.3fns max=%0.3fns; admission->PCM=%0d clocks; admission->frame=104 clocks; nonzero=%0d; real I2S L/R exact, zero underruns, production warmup1024. External ADC/DAC excluded.",LOAD,min_ns,max_ns,min_m,nonzero);
 $finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule


