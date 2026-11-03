`timescale 1ns/1ps
module tb_pressure_gain;
    reg clk=0,rst_n=0;
    always #20.325203252 clk=~clk;
    reg [63:0] raw=0;
    reg [7:0] valid=0;
    wire [7:0] held;
    wire bclk,lrclk,din,xsmt;
    wire [15:0] underruns;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8)) dut(clk,rst_n,valid,raw,held,bclk,lrclk,din,xsmt,underruns,2'd0);
    initial forever begin #1000000;@(negedge clk);valid=255;@(negedge clk);valid=0;end
    integer index=0,frames=0,sample=0,abs_sample,peak=0;
    reg [15:0] left=0,right=0;
    reg aligned=0,last_lr=0,measure=0;
    always @(posedge bclk) if(rst_n) begin
        if(last_lr && !lrclk) begin index=0;aligned=1;end
        if(aligned) begin
            if(lrclk !== (index>=32)) $fatal(1,"I2S slot");
            if(index==0 || index==32 || (index>16 && index<32) || index>48)
                if(din!==0) $fatal(1,"I2S padding");
            if(index>=1 && index<=16) left[16-index]=din;
            if(index>=33 && index<=48) right[48-index]=din;
            if(index==63) begin
                if(left!==right) $fatal(1,"Stereo mismatch");
                sample=$signed(left);abs_sample=sample<0?-sample:sample;
                if(measure && abs_sample>peak) peak=abs_sample;
                frames=frames+1;
            end
            index=(index+1)%64;
        end
        last_lr=lrclk;
    end
    task get_peak;
        output integer value;
        integer start_frame;
        begin
            @(negedge clk);peak=0;measure=1;start_frame=frames;
            wait(frames>=start_frame+1024);
            @(negedge clk);value=peak;measure=0;
        end
    endtask
    integer p64,p128,p255,p11,p0,k;
    initial begin
        #1000;rst_n=1;#2000000;
        if(held!=0 || sample!=0 || !xsmt) $fatal(1,"Idle startup");
        raw[7:0]=9;#3000000;if(held!=0 || sample!=0) $fatal(1,"Below threshold audible");
        raw[7:0]=10;#3000000;if(held!==0) $fatal(1,"Pressure 10 must stay off"); raw[7:0]=11;#3000000;if(held!==0) $fatal(1,"Pressure 11 must stay off"); raw[7:0]=20;#3000000;if(held!==1) $fatal(1,"Pressure 20 must start voice");
        // Let original ADSR reach sustain; amplitude comparisons must not
        // confuse the attack/decay envelope with pressure response.
        raw[7:0]=64;#65000000;get_peak(p64);
        if(dut.notes[0].note.env.state!=3) $fatal(1,"Not in ADSR sustain");
        raw[7:0]=128;#3000000;get_peak(p128);
        raw[7:0]=255;#3000000;get_peak(p255);
        if(p64<10 || p128<=p64 || p255<=p128) $fatal(1,"Pressure amplitude not monotonic");
        if(p128*100<p64*195 || p128*100>p64*205) $fatal(1,"64->128 gain not linear: %0d %0d",p64,p128);
        if(p255*128<p128*250 || p255*128>p128*260) $fatal(1,"128->255 gain not linear");
        raw[7:0]=11;#3000000;get_peak(p11);
        if(held!==1 || p11==0 || p11>=p64) $fatal(1,"Light pressure must remain audible");
        raw=0;#3000000;if(held!=0) $fatal(1,"Release state");
        if(dut.notes[0].note.env.state!=4) $fatal(1,"Missing ADSR release");
        #80000000;get_peak(p0);if(p0!=0) $fatal(1,"Release not silent");
        for(k=0;k<10;k=k+1) begin
            raw[7:0]=64;#3000000;if(held!==1) $fatal(1,"Repeat press %0d",k);
            raw=0;#3000000;if(held!=0) $fatal(1,"Repeat release %0d",k);
        end
        #80000000;get_peak(p0);
        if(p0!=0 || underruns!=0) $fatal(1,"Final silence/underrun");
        $display("PASS GAIN: decoded I2S PCM increases linearly with pressure, 64=%0d 128=%0d 255=%0d 11=%0d; threshold, original ADSR, 10 retriggers, final zero",p64,p128,p255,p11);
        $finish;
    end
    initial begin #600000000;$fatal(1,"Gain timeout");end
endmodule


