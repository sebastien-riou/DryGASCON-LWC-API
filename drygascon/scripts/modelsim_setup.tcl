# -----------------------------------------------------------------------------
# Setup
set KAT_FOLDER "KAT"
if [catch {set LAST_COMPILE_TIME}] {
    puts "Clearing time ..."
    set LAST_COMPILE_TIME 0
}

# Default values
namespace eval ns {
  variable LIB_DIR     ./libs
  variable WORK_LIB    [subst $LIB_DIR/work]
}

proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib} }

proc prep_work {} {
    puts "Creating a library folder ..."
    global LAST_COMPILE_TIME
    ensure_lib         $ns::LIB_DIR
    ensure_lib         [subst $ns::WORK_LIB]
    vmap work          [subst $ns::WORK_LIB]
    uplevel #0 [list set LAST_COMPILE_TIME 0]
    if {![file exists KAT]} {
      puts "Creating KAT folder"
      file mkdir KAT
      file copy "../KAT/sdi.txt" "KAT/sdi.txt"
      file copy "../KAT/pdi.txt" "KAT/pdi.txt"
      file copy "../KAT/do.txt" "KAT/do.txt"
    }
    puts "...done"
}

# if {$LAST_COMPILE_TIME < [file mtime $file]} {
# Incremental compilation
proc incr_compile {lib files} {
    puts "\[incr_compile\] Start ..."
    global RTL_PATH
    global LAST_COMPILE_TIME
    puts "==Last compile time $LAST_COMPILE_TIME"
    foreach file $files {
        if [regexp {.vh$} $file] {
          puts "Skipped $file (package file)"
          continue
        }
        # Extract entity name
        regexp {\w+} [file tail $file] matched
        set entity_name $matched
        # Get last compilation time
        set lastmod [file mtime $file]

        # Compile if file is modified
        if {$LAST_COMPILE_TIME < $lastmod} {
            if [regexp {.vhdl?$} $file] {
                puts "vcom -quiet -work $lib $file"
                vcom -quiet -work $lib $file
            } else {
                puts "vlog +define+SIMULATION +incdir+$RTL_PATH -quiet -work $lib $file"
                vlog  +define+SIMULATION +incdir+$RTL_PATH -quiet -work $lib $file
            }
        } else {
            puts "  Skipping $file"
        }
    }

    # Update last compilation time
    set LAST_COMPILE_TIME [clock seconds]
    puts "\[incr_compile\] Done"
}

# Alias

alias clean_work {
    vdel -all
    prep_work
}

alias u {
    source modelsim.tcl
}
alias uu {
    source modelsim.tcl
    clean_work
}

alias q {
    source modelsim.tcl
    prep_work
}

alias cc {
    puts "incr_compile $ns::WORK_LIB [concat $src_rtl $src_tb]"
    incr_compile $ns::WORK_LIB [concat $src_rtl $src_tb]
}

alias sim {
    vsim -gui -t ps -L work -gG_FNAME_PDI="KAT/pdi.txt" -gG_FNAME_SDI="KAT/sdi.txt" -gG_FNAME_DO="KAT/do.txt" lwc_tb
    if {[file isfile wave.do]} {
      do wave.do
    }
    run $RUN_TIME
}

alias r {
    cc
    sim
}

# Preparing the library
if {(![file isdirectory $ns::LIB_DIR] || ![file isdirectory $ns::WORK_LIB])} {
    prep_work
}

