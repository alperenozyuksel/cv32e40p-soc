# Run with: vivado -mode batch -source scripts/create_project.tcl
# This creates a project only; it does not launch simulation or synthesis.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $repo_root build vivado]
create_project cv32e40p_soc $project_dir -part xc7vx485tffg1157-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Match the original Vivado source selection: FF register file, FPU disabled.
set fh [open [file join $repo_root scripts core_sources.flist] r]
set source_lines [split [read $fh] "\n"]
close $fh
foreach source_line $source_lines {
    set source_line [string trim $source_line]
    if {$source_line ne ""} {
        add_files -norecurse [file join $repo_root $source_line]
    }
}
set_property include_dirs [list [file join $repo_root third_party cv32e40p rtl include]] [get_filesets sources_1]
set clock_gate [get_files *cv32e40p_sim_clock_gate.sv]
set_property used_in_synthesis false $clock_gate

foreach relative_path {
    rtl/soc_top.sv
    rtl/memory/imem_8kb.sv
    rtl/memory/dmem_8kb.sv
    rtl/interconnect/adres_yonlendirici.sv
    rtl/peripherals/gpio.sv
} {
    add_files -norecurse [file join $repo_root $relative_path]
}
set_property top soc_top [get_filesets sources_1]

foreach relative_path {tb/tb_soc.sv tb/tb_imem_8kb.sv} {
    add_files -fileset sim_1 -norecurse [file join $repo_root $relative_path]
}
set image_path [file join $repo_root sw tests basic program.hex]
add_files -fileset sim_1 -norecurse $image_path
set_property file_type {Memory Initialization Files} [get_files $image_path]
set_property top tb_soc [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Project created: [file join $project_dir cv32e40p_soc.xpr]"
