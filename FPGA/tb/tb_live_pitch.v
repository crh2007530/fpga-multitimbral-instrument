`timescale 1ns/1ps
module tb_live_pitch;
    reg clk=0;always #20.325203252 clk=~clk;
    reg rst=0;reg [63:0] raw=0;reg [1:0] mode=0;
    wire [7:0] held;wire bclk,lrclk,din,xsmt;wire [15:0] underruns;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8),.DYNAMIC_PITCH(1)) dut(
        .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.held(held),
        .bclk(bclk),.lrclk(lrclk),.din(din),.xsmt(xsmt),.underruns(underruns),.pitch_mode(mode));
    integer ix=0,frames=0,sample,n=0,j;
    reg aligned=0,last_lr=0,measure=0;
    reg [15:0] left=0,right=0;
    real f[0:1];real cs[0:1];real sn[0:1];real mag;
    always @(posedge bclk) if(rst) begin
        if(last_lr && !lrclk) begin ix=0;aligned=1;end
        if(aligned) begin
            if(ix>=1 && ix<=16) left[16-ix]=din;
            if(ix>=33 && ix<=48) right[48-ix]=din;
            if(ix==63) begin
                if(left!==right) $fatal(1,"stereo");
                sample=$signed(left);frames=frames+1;
                if(measure) begin
                    for(j=0;j<2;j=j+1) begin
                        cs[j]=cs[j]+sample*$cos(6.28318530718*f[j]*n/48046.875);
                        sn[j]=sn[j]+sample*$sin(6.28318530718*f[j]*n/48046.875);
                    end
                    n=n+1;
                end
            end
            ix=(ix+1)%64;
        end
        last_lr=lrclk;
    end
    reg [31:0] prior0,prior1,inc,inc1;
    task pitch;
        input [1:0] m;input real hz;
        begin
            @(negedge clk);mode=m;
            inc=m==1 ? 23387020 : m==2 ? 93548082 : 46774041;
            inc1=m==1 ? 26251043 : m==2 ? 105004172 : 52502086;
            // Both independent notes follow the selected octave continuously.
            repeat(40) begin
                @(negedge clk);wait(dut.sample_ce);@(posedge clk);
                begin
                    prior0=dut.notes[0].note.sine.phase_acc;
                    prior1=dut.notes[1].note.sine.phase_acc;
                    #1;
                    if(dut.notes[0].note.sine.phase_acc!==prior0+inc) $fatal(1,"voice0 phase discontinuity");
                    if(dut.notes[1].note.sine.phase_acc!==prior1+inc1) $fatal(1,"voice1 phase discontinuity");
                end
                if(held!==3 || dut.notes[0].note.env.state!==3 || dut.notes[1].note.env.state!==3)
                    $fatal(1,"pitch retrigger/release");
            end
            #1000000;f[0]=hz;f[1]=(m==1) ? 293.664768 : (m==2) ? 1174.659072 : 587.329536;n=0;
            for(j=0;j<2;j=j+1) begin cs[j]=0;sn[j]=0;end
            measure=1;wait(n>=2048);measure=0;
            for(j=0;j<2;j=j+1) begin
                mag=2*$sqrt(cs[j]*cs[j]+sn[j]*sn[j])/n;
                if(mag<500) $fatal(1,"I2S tone missing mode=%d hz=%f amplitude=%f",m,f[j],mag);
                $display("PASS LIVE I2S mode=%d hz=%f amplitude=%f",m,f[j],mag);
            end
        end
    endtask
    initial begin
        #1000;rst=1;#2000000;mode=2;#1000000;
        if(held!==0 || sample!==0) $fatal(1,"touch alone audible");
        raw=64'hffff;#60000000;
        pitch(0,523.251131);pitch(1,261.625565);pitch(2,1046.502261);pitch(0,523.251131);
        raw[7:0]=0;#80000000;
        if(held!==2 || dut.notes[0].note.pcm!==0) $fatal(1,"independent release");
        raw=0;#80000000;
        if(held!==0 || sample!==0 || underruns!==0) $fatal(1,"final silence/underrun");
        $display("PASS LIVE: shared octave on Z1/Z2 actual I2S, continuous phases, no ADSR retrigger, independent release, touch alone silent");$finish;
    end
    initial begin #600000000;$fatal(1,"timeout");end
endmodule
