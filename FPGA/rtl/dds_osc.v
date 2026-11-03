`timescale 1ns/1ps
// Run tools from the module root so the default relative ROM path resolves.
module dds_osc #(
    parameter integer DUAL_WAVE=0,
    parameter ROM_FILE = "assets/sine_1024_16.hex"
)(
    input wire [0:0] clk,
    input wire [0:0] rst_n,
    input wire [0:0] sample_ce,
    input wire [0:0] enable,
    input wire [31:0] phase_inc,
    output reg signed [15:0] sample_out,
    output reg [0:0] sample_valid, input wire sine_mode
);
    reg [31:0] phase_acc;
    reg [15:0] sine_rom [0:1023];
    reg signed [15:0] rom_q;
    wire [15:0] pure_q;
    generate if(DUAL_WAVE) begin: pure_wave
      reg [15:0] table_rom[0:1023];
      reg [15:0] q;
      initial $readmemh("assets/sine_1024_16.hex",table_rom);
      always @(posedge clk) if(sample_ce) q<=table_rom[phase_acc[31:22]];
      assign pure_q=q;
    end else assign pure_q=0; endgenerate
    reg wave_d;
    always @(posedge clk) if(sample_ce) wave_d<=sine_mode;
    reg ce_d;
    reg enable_d;

    initial begin
        $readmemh(ROM_FILE, sine_rom);
    end

    // No reset on the ROM read register: permits synchronous BSRAM inference.
    // The pipeline validity registers mask its undefined power-on value.
    always @(posedge clk) begin
        if (sample_ce)
            rom_q <= sine_rom[phase_acc[31:22]];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
            ce_d <= 1'b0;
            enable_d <= 1'b0;
            sample_out <= 16'sd0;
            sample_valid <= 1'b0;
        end else begin
            ce_d <= sample_ce;
            enable_d <= enable;
            sample_valid <= ce_d;
            if (sample_ce && enable)
                phase_acc <= phase_acc + phase_inc;
            // Disable also cancels a pending audible sample at this edge.
            if (!enable)
                sample_out <= 16'sd0;
            else if (ce_d)
                sample_out <= enable_d ? ((DUAL_WAVE && wave_d) ? $signed(pure_q) : rom_q) : 16'sd0;
        end
    end
endmodule
