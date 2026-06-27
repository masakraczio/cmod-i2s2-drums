set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]

create_project psram_smoke_check [file join $project_dir .psram_smoke_check] -part xc7a35tcpg236-1 -force
set source_files [list \
    [file normalize [file join $project_dir src psram_spi_master.sv]] \
    [file normalize [file join $project_dir src psram_pattern_tester.sv]] \
    [file normalize [file join $project_dir src cmod_psram_smoke_top.sv]] \
]

add_files -norecurse $source_files
set_property top cmod_psram_smoke_top [current_fileset]
update_compile_order -fileset sources_1
synth_design -rtl -top cmod_psram_smoke_top -part xc7a35tcpg236-1

puts "PSRAM smoke-test top elaborated successfully."
