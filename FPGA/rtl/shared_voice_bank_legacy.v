`timescale 1ns/1ps
// GROUP independent voices share a waveform ROM pair and two multipliers.
// Inputs must remain stable until publication at GROUP+5 clocks.
// Production GROUP=8, request interval=512 clocks.
module shared_voice_bank_legacy #(parameter integer VOICES=32, GROUP=4, THIRD_TIMBRE=0)(
 input wire clk,rst_n,sample_ce,sine_mode,
 input wire [VOICES*10-1:0] addresses,
 input wire [VOICES*16-1:0] forces,envelopes,
 output wire [VOICES*16-1:0] samples,output wire valid,input wire epiano_mode,input wire diagnostic_mode);
 localparam SW=$clog2(GROUP);
 reg [GROUP+4:0] stages;
 reg wave,piano,diagnostic;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin stages<=0;wave<=0;piano<=0;diagnostic<=0;end
 else begin stages<={stages[GROUP+3:0],sample_ce};if(sample_ce)begin wave<=sine_mode;piano<=THIRD_TIMBRE && epiano_mode;diagnostic<=diagnostic_mode;end end
 // Launch slots at request+3 onward; commit two cycles later.
 wire launch=|stages[GROUP+1:2];
 reg [SW-1:0] slot; integer k;
 always @* begin slot=0;for(k=0;k<GROUP;k=k+1)if(stages[k+2])slot=k;end
 assign valid=stages[GROUP+4];
 genvar g,s;
 generate for(g=0;g<VOICES/GROUP;g=g+1)begin: lanes
  wire signed[15:0] selected_wave;
  if(THIRD_TIMBRE)begin: three_presets
   reg[15:0] instrument_rom[0:2047];reg signed[15:0] waveform_q;
   // 32K ROM bits/lane: diagnostic sine1024, reed256, dizi256, piano512.
   // Diagnostic tones bypass all instrument-specific colour and breath.
   wire[10:0] rom_address=diagnostic?{1'b0,address}:piano?{2'b11,address[9:1]}:
       wave?{3'b101,address[9:2]}:{3'b100,address[9:2]};
   initial $readmemh("assets/instruments_2048_16.hex",instrument_rom);
   always @(posedge clk)if(launch)waveform_q<=instrument_rom[rom_address];
   assign selected_wave=waveform_q;
  end else begin: legacy_presets
   reg[15:0] bright_rom[0:1023],sine_rom[0:1023];reg signed[15:0] waveform_q;
   initial begin $readmemh("assets/bright_1024_16.hex",bright_rom);$readmemh("assets/sine_1024_16.hex",sine_rom);end
   always @(posedge clk)if(launch)waveform_q<=wave?sine_rom[address]:bright_rom[address];
   assign selected_wave=waveform_q;
  end
  wire [GROUP*10-1:0] lane_addresses=addresses[g*GROUP*10+:GROUP*10];
  wire [GROUP*16-1:0] lane_forces=forces[g*GROUP*16+:GROUP*16];
  wire [GROUP*16-1:0] lane_envelopes=envelopes[g*GROUP*16+:GROUP*16];
  wire [9:0] address=lane_addresses[slot*10+:10];
  wire [15:0] force_in=lane_forces[slot*16+:16];
  wire [15:0] env_in=lane_envelopes[slot*16+:16];
  reg [31:0] gain_product;
  reg signed [32:0] audio_product;
  reg v1,v2;
  reg [SW-1:0] slot1,slot2;
  reg signed [15:0] output_samples[0:GROUP-1];
  // Each piano voice has its own damping history. The hammer is bright;
  // upper partials decay faster as its amplitude envelope falls.
  reg signed[15:0] damping[0:GROUP-1];reg[1:0] damping_shift;
  wire signed[16:0] damp_delta=$signed({selected_wave[15],selected_wave})-$signed({damping[slot1][15],damping[slot1]});
  wire signed[16:0] damp_sum=$signed({damping[slot1][15],damping[slot1]})+(damp_delta>>>damping_shift);
  wire signed[15:0] damped_sample=piano?damp_sum[15:0]:selected_wave;
  // Small deterministic excitation, decorrelated per arithmetic lane.
  // The gain envelope silences it completely when the voice is inactive.
  reg[22:0] noise_state;reg signed[15:0] excitation;reg[15:0] env_q;
  wire signed[15:0] noise_value=noise_state[22:7];
  wire signed[16:0] coloured=$signed({damped_sample[15],damped_sample})+$signed({excitation[15],excitation});
  wire signed[15:0] instrument_sample=coloured>32767?16'sh7fff:coloured< -32768?16'sh8000:coloured[15:0];
  integer i;
  always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
    v1<=0;v2<=0;slot1<=0;slot2<=0;gain_product<=0;audio_product<=0;
    damping_shift<=0;noise_state<=23'h5a691d^(g*23'h12345);excitation<=0;env_q<=0;
    for(i=0;i<GROUP;i=i+1)begin output_samples[i]<=0;damping[i]<=0;end
   end else begin
    v1<=launch;v2<=v1;
    if(launch)begin gain_product<=force_in*env_in;slot1<=slot;env_q<=env_in;
     noise_state<={noise_state[21:0],noise_state[22]^noise_state[17]};
     excitation<=(!THIRD_TIMBRE || diagnostic)?16'sd0:
       piano?((env_in>30000)?(noise_value>>>6):16'sd0):
       wave?((env_in<8192)?(noise_value>>>5):(noise_value>>>7)):(noise_value>>>9);
     damping_shift<=env_in>=24576?2'd0:env_in>=16384?2'd1:2'd2;end
    if(v1)begin
     damping[slot1]<=damped_sample;
     audio_product<=$signed(instrument_sample)*$signed({1'b0,gain_product[30:15]});
     slot2<=slot1;
    end
    // Piano-only +6.02 dB; 33-bit product shifts before 16-bit storage.
    if(v2)output_samples[slot2]<=audio_product>>>(piano?16:17);
   end
  end
  for(s=0;s<GROUP;s=s+1)begin: outputs
   assign samples[(g*GROUP+s)*16+:16]=output_samples[s];
  end
 end endgenerate
endmodule


