create_clock -name clk_50m -period 20.000 [get_ports {clk_50m}]
create_generated_clock -name audio_clk -source [get_ports {clk_50m}] -multiply_by 123 -divide_by 250 [get_pins {u_audio_pll/u_pll/PLLA_inst/CLKOUT0}]
set_clock_groups -asynchronous -group [get_clocks {clk_50m}] -group [get_clocks {audio_clk}]
set_false_path -from [get_ports {pluck_ir adc0_scl adc0_sda adc1_scl adc1_sda oled_sda ttp_sdo apds_sda}]
set_output_delay -clock audio_clk -max 20.000 [get_ports {i2s_bclk i2s_lrclk i2s_din xsmt pcm2_bclk pcm2_lrclk pcm2_din pcm2_xsmt}]
set_output_delay -clock audio_clk -min 0.000 [get_ports {i2s_bclk i2s_lrclk i2s_din xsmt pcm2_bclk pcm2_lrclk pcm2_din pcm2_xsmt}]
# UART has its own asynchronous baud timing; an LED has no capture clock.
# Their internal registers remain timed, but neither pin is a 50MHz receiver.
set_false_path -to [get_ports {debug_tx status_led dout ttp_scl oled_scl oled_sda apds_scl apds_sda}]

# Async UART: only first RX synchronizer input is excluded; synchronizer and
# decode pipeline remain timed. TX receiver has no synchronous capture clock.
set_false_path -from [get_ports {bt_rx}]
set_false_path -to [get_ports {bt_tx}]

create_generated_clock -name video_serial -source [get_ports {clk_50m}] -multiply_by 89 -divide_by 12 [get_pins {u_video_pll/u_pll/PLLA_inst/CLKOUT0}]
create_generated_clock -name video_pixel -source [get_ports {clk_50m}] -multiply_by 89 -divide_by 60 [get_pins {u_video_pll/u_pll/PLLA_inst/CLKOUT1}]
# Keep serializer and pixel domains related. Only asynchronous mailbox/RAM crossings are grouped.
set_clock_groups -asynchronous -group [get_clocks {clk_50m}] -group [get_clocks {audio_clk}] -group [get_clocks {video_serial video_pixel}]

# Static termination enable, no receiver clock.
set_false_path -to [get_ports {hdmi_power}]

# Startup timing contract (video_serializer_start): RESET deasserts while
# FCLK is stopped by DHCE. Gate enable follows eight pixel periods later
# (>107ns), then four fast-clock falling-edge synchronizer stages.
# Bound ONLY fast-clock recovery paths to 50ns (< half the startup guard).
# Pixel-clock recovery remains on its original 13.48ns timing requirement.
# All normal pixel/serial DATA paths remain related and fully timed.
set_max_delay -from [get_clocks {video_pixel}] -to [get_clocks {video_serial}] -through [get_pins {video_output/rgb2dvi_inst/u_OSER10_clk/RESET video_output/rgb2dvi_inst/u_OSER10_b/RESET video_output/rgb2dvi_inst/u_OSER10_g/RESET video_output/rgb2dvi_inst/u_OSER10_r/RESET}] 50.000

# DHCE contains FOUR falling-edge synchronizer registers (official gw5a
# prim_sim.v ce_reg0..ce_reg3). CEN is an asynchronous, persistent request,
# not a data item required at the first FCLK edge. Exclude only the input
# of that hard synchronizer. No downstream datapath is excluded.
set_false_path -from [get_pins {video_start/gate_disable_s0/Q}] -to [get_pins {video_start/fast_gate/CEN}]

# Reserve 0.400ns for setup/recovery optimization; actual PLL frequencies unchanged.
set_clock_uncertainty 0.400 -setup -from [get_clocks {clk_50m audio_clk video_pixel}]
