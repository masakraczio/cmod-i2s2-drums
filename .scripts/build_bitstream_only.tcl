set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set project_name pmod_i2s2_drums
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
}

set source_files [list \
    [file normalize [file join $project_dir src cmod_i2s2_drums.sv]] \
    [file normalize [file join $project_dir src drum_audio_engine.sv]] \
    [file normalize [file join $project_dir src drum_audio_engine_sram.sv]] \
    [file normalize [file join $project_dir src psram_spi_master.sv]] \
    [file normalize [file join $project_dir src psram_pattern_tester.sv]] \
    [file normalize [file join $project_dir src cmod_psram_smoke_top.sv]] \
    [file normalize [file join $project_dir src onboard_sram_controller.sv]] \
    [file normalize [file join $project_dir src onboard_sram_pattern_tester.sv]] \
]
set xdc_file [file normalize [file join $project_dir constrs cmod_i2s2_drums.xdc]]

foreach src_file $source_files {
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

puts "Generated bitstream without programming hardware."
