set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $script_dir ..]]
set bit_file [file join $project_dir pmod_i2s2_drums.runs impl_1 cmod_i2s2_drums.bit]

if {![file exists $bit_file]} {
    error "Bitstream was not found: $bit_file"
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
