`timescale 1ns/1ps
module tb_poly8_voice;
    reg clk=0;always #20.325203252 clk=~clk;
    reg rst_n=0;
    reg [63:0] raw=0;
    reg [7:0] valid=0,stream=255;
    wire [7:0] held;
    wire bclk,lrclk,din,xsmt;
    wire [15:0] underruns;
    pcm_pressure_poly8 #(.WARMUP_FRAMES(8)) dut(clk,rst_n,valid,raw,held,bclk,lrclk,din,xsmt,underruns,2'd0);
    initial forever begin #1000000;@(negedge clk);valid=stream;@(negedge clk);valid=0;end
    integer index=0,frames=0,sample,abs_sample,peak=0,measured=0,n;
    reg [15:0] left=0,right=0;
    reg aligned=0,last_lr=0,spectrum=0;
    real freq[0:7];real corr_s[0:7];real corr_c[0:7];real magnitude;
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
                sample=$signed(left);abs_sample=sample<0 ? -sample : sample;
                if(abs_sample>peak) peak=abs_sample;
                frames=frames+1;
                if(spectrum) begin
                    for(n=0;n<8;n=n+1) begin
                        corr_s[n]=corr_s[n]+sample*$sin(6.283185307179586*freq[n]*measured/48046.875);
                        corr_c[n]=corr_c[n]+sample*$cos(6.283185307179586*freq[n]*measured/48046.875);
                    end
                    measured=measured+1;
                end
            end
            index=(index+1)%64;
        end
        last_lr=lrclk;
    end
    integer ch;
    initial begin
        freq[0]=523.251131;freq[1]=587.329536;freq[2]=659.255114;freq[3]=698.456463;
        freq[4]=783.990872;freq[5]=880.0;freq[6]=987.766603;freq[7]=1046.502261;
        for(ch=0;ch<8;ch=ch+1) begin corr_s[ch]=0;corr_c[ch]=0;end
        #1000;rst_n=1;#2000000;
        if(held!=0 || peak!=0 || !xsmt) $fatal(1,"Startup silence");
        raw=64'hffffffffffffffff;#6000000;
        if(held!==255) $fatal(1,"Eight notes missing");
        spectrum=1;wait(measured>=4096);spectrum=0;
        for(ch=0;ch<8;ch=ch+1) begin
            magnitude=2*$sqrt(corr_s[ch]*corr_s[ch]+corr_c[ch]*corr_c[ch])/measured;
            if(magnitude<500) $fatal(1,"Mixed tone missing ch%0d magnitude=%f",ch,magnitude);
            $display("PASS eight-note mixed spectrum ch%0d f=%f amplitude=%f",ch,freq[ch],magnitude);
        end
        // Lose only ADC0 updates: notes 0..3 release, notes 4..7 stay held.
        stream=240;#12000000;
        if(held!==240) $fatal(1,"ADC0 loss affected ADC1 held=%h",held);
        // Release just the fifth physical pad, keeping three higher notes held.
        raw[39:32]=0;#2000000;
        if(held!==224) $fatal(1,"Independent upper-note release held=%h",held);
        raw=0;#80000000;peak=0;#3000000;
        if(held!=0 || peak!=0 || underruns!=0) $fatal(1,"Release/underrun held=%h peak=%0d underruns=%0d",held,peak,underruns);
        $display("PASS poly8: all eight spectral components, I2S stereo/padding, bounded signed mix, independent upper-pad release, ADC0 stale isolation, final silence; frames=%0d",frames);
        $finish;
    end
    initial begin #300000000;$fatal(1,"Timeout");end
endmodule
