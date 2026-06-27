set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set project_name pmod_i2s2_drums
set bit_file [file join $project_dir $project_name.runs impl_1 cmod_i2s2_drums.bit]
set board_repo "C:/Users/pepas/AppData/Roaming/Xilinx/Vivado/2025.2/xhub/board_store/xilinx_board_store/XilinxBoardStore/Vivado/2025.2/boards"

cd $project_dir
if {[file exists $board_repo]} {
    set_param board.repoPaths $board_repo
}

if {[file exists [file join $project_dir $project_name.xpr]]} {
    open_project [file join $project_dir $project_name.xpr]
} else {
    create_project $project_name $project_dir -part xc7a35tcpg236-1
}

if {[llength [get_board_parts -quiet digilentinc.com:cmod_a7-35t:part0:1.2]] > 0} {
    set_property board_part digilentinc.com:cmod_a7-35t:part0:1.2 [current_project]
} else {
    puts "WARNING: CMOD A7 board_part was not found; continuing with xc7a35tcpg236-1 and explicit XDC constraints."
}

set top_file [file normalize [file join $project_dir src cmod_i2s2_drums.sv]]
set engine_file [file normalize [file join $project_dir src drum_audio_engine.sv]]
set engine_sram_file [file normalize [file join $project_dir src drum_audio_engine_sram.sv]]
set psram_master_file [file normalize [file join $project_dir src psram_spi_master.sv]]
set psram_tester_file [file normalize [file join $project_dir src psram_pattern_tester.sv]]
set psram_smoke_file [file normalize [file join $project_dir src cmod_psram_smoke_top.sv]]
set onboard_sram_file [file normalize [file join $project_dir src onboard_sram_controller.sv]]
set onboard_sram_tester_file [file normalize [file join $project_dir src onboard_sram_pattern_tester.sv]]
set xdc_file [file normalize [file join $project_dir constrs cmod_i2s2_drums.xdc]]

foreach src_file [list $top_file $engine_file $engine_sram_file $psram_master_file $psram_tester_file $psram_smoke_file $onboard_sram_file $onboard_sram_tester_file] {
    if {[llength [get_files -quiet $src_file]] == 0} {
        add_files -norecurse $src_file
    }
}
if {[llength [get_files -quiet $xdc_file]] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc_file
}

set_property include_dirs [file normalize [file join $project_dir src]] [current_fileset]
set_property top cmod_i2s2_drums [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis did not complete"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation or bitstream generation did not complete"
}

if {![file exists $bit_file]} {
    error "Bitstream was not generated: $bit_file"
}

open_hw_manager
connect_hw_server
open_hw_target

set devices [get_hw_devices *xc7a35t*]
if {[llength $devices] == 0} {
    error "No xc7a35t device found over JTAG"
}

set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device $dev
set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "Programmed $dev with $bit_file"
