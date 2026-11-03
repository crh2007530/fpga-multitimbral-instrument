`timescale 1ns/1ps
`include "tb/pressure_voice_state_v18_reference.v"
module tb_shared_stale_equivalence;
reg clk=0;always #5 clk=~clk;
reg rst=0,sv=0,pv=0,enabled=0,testmode=0,base_enabled=1;
reg[7:0]raw=0;reg[31:0]inc=32'd12345678;
reg guitar=0,piano=0,phase0=0,phase1=0;
wire stale;
wire[1:0]h,a,hr,ar;wire[19:0]addr,addrr;wire[31:0]f,e,step,fr,er,stepr;
wire[7:0]base_raw=testmode?(base_enabled?8'd96:0):raw;
wire[7:0]upper_raw=testmode?(enabled?8'd96:0):(enabled?raw:0);
pressure_voice_state #(.AUDIO_HZ(2000),.DEFER_PHASE(1),.INSTRUMENTS(1),.THIRD_TIMBRE(1)) base(
 .clk(clk),.rst_n(rst),.sample_ce(sv),.pressure_valid(testmode||pv),.phase_ce(phase0),.flute_mode(guitar),.test_mode(testmode),
 .pressure_raw(base_raw),.phase_inc(inc),.held(h[0]),.envelope_active(a[0]),.address(addr[9:0]),.force_snapshot(f[15:0]),.envelope_snapshot(e[15:0]),.epiano_mode(piano),.increment_snapshot(step[15:0]),.shared_stale(1'b0),.stale_out(stale));
pressure_voice_state #(.AUDIO_HZ(2000),.DEFER_PHASE(1),.INSTRUMENTS(1),.THIRD_TIMBRE(1),.SHARED_STALE(1)) upper(
 .clk(clk),.rst_n(rst),.sample_ce(sv),.pressure_valid(testmode||!enabled||pv),.phase_ce(phase1),.flute_mode(guitar),.test_mode(testmode),
 .pressure_raw(upper_raw),.phase_inc(inc>>1),.held(h[1]),.envelope_active(a[1]),.address(addr[19:10]),.force_snapshot(f[31:16]),.envelope_snapshot(e[31:16]),.epiano_mode(piano),.increment_snapshot(step[31:16]),.shared_stale(stale),.stale_out());
pressure_voice_state_v18_reference #(.AUDIO_HZ(2000),.DEFER_PHASE(1),.INSTRUMENTS(1),.THIRD_TIMBRE(1)) base_ref(
 .clk(clk),.rst_n(rst),.sample_ce(sv),.pressure_valid(testmode||pv),.phase_ce(phase0),.flute_mode(guitar),.test_mode(testmode),
 .pressure_raw(base_raw),.phase_inc(inc),.held(hr[0]),.envelope_active(ar[0]),.address(addrr[9:0]),.force_snapshot(fr[15:0]),.envelope_snapshot(er[15:0]),.epiano_mode(piano),.increment_snapshot(stepr[15:0]));
pressure_voice_state_v18_reference #(.AUDIO_HZ(2000),.DEFER_PHASE(1),.INSTRUMENTS(1),.THIRD_TIMBRE(1)) upper_ref(
 .clk(clk),.rst_n(rst),.sample_ce(sv),.pressure_valid(testmode||!enabled||pv),.phase_ce(phase1),.flute_mode(guitar),.test_mode(testmode),
 .pressure_raw(upper_raw),.phase_inc(inc>>1),.held(hr[1]),.envelope_active(ar[1]),.address(addrr[19:10]),.force_snapshot(fr[31:16]),.envelope_snapshot(er[31:16]),.epiano_mode(piano),.increment_snapshot(stepr[31:16]));
integer n,seed=180026,changes=0,stale_releases=0;reg[1:0]last_h=0;
always @(posedge clk)if(rst)begin
 #1;
 if({h,a,addr,f,e,step}!=={hr,ar,addrr,fr,er,stepr})$fatal(1,"shared watchdog mismatch at cycle %d",n);
 if(h!=last_h)changes=changes+1;
 if(last_h[1]&&!h[1]&&stale&&!testmode&&enabled&&!pv)stale_releases=stale_releases+1;
 last_h=h;
end
initial begin
repeat(4)@(negedge clk);rst=1;
for(n=0;n<300000;n=n+1)begin
 @(negedge clk);sv=n%8==0;phase0=n%8==2;phase1=n%8==5;
 pv=($random(seed)&63)==0;
 if(($random(seed)&15)==0)raw=$random(seed);
 if(($random(seed)&31)==0)enabled=~enabled;
 if(($random(seed)&255)==0)testmode=~testmode;
 if(($random(seed)&127)==0)base_enabled=~base_enabled;
 if(($random(seed)&511)==0)begin guitar=$random(seed);piano=$random(seed);inc=$random(seed);end
end
@(negedge clk);
if(changes<1000||stale_releases<100)$fatal(1,"insufficient watchdog coverage");
$display("PASS shared pressure watchdog exact output equivalence for 300000 cycles: chord/enable toggles, test masks/mode changes, ADC dropouts, note/phase/envelope snapshots; changes=%d stale_releases=%d",changes,stale_releases);$finish;
end
endmodule
