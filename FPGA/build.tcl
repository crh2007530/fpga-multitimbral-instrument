set project_dir [file dirname [file normalize [info script]]]
cd $project_dir
open_project [file join $project_dir pressure_ws2812_dualpcm.gprj]
set_option -top_module pressure_poly8_top
set_option -output_base_name console60_HDMI64
set_option -vccx 1.8
set_option -use_sspi_as_gpio 1
set_option -use_cpu_as_gpio 1
set_option -place_option 4
set_option -route_option 2
run all
exit


