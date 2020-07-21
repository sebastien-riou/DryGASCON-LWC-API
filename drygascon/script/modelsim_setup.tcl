# -----------------------------------------------------------------------------
# Setup
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
    puts "...done"
}

# if {$LAST_COMPILE_TIME < [file mtime $file]} {
# Incremental compilation
proc incr_compile {lib files} {
    puts "\[incr_compile\] Start ..."
    global LAST_COMPILE_TIME
    puts "==Last compile time $LAST_COMPILE_TIME"
    foreach file $files {
        # Extract entity name
        regexp {\w+} [file tail $file] matched
        set entity_name $matched
        # Get last compilation time
        set lastmod [file mtime $file]
        # Compile if file is modified or not exist in workspace
        if {$LAST_COMPILE_TIME < $lastmod || [catch {vdir $matched}]} {
            if [regexp {.vhdl?$} $file] {
                puts "vcom -quiet -work $lib $file"
                vcom -quiet -work $lib $file
            } elseif [regexp {.vh$} $file] {
                puts "Skipped $file (package file)"
            } else {
                puts "vlog -quiet -work $lib $file"
                vlog -quiet -work $lib $file
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

alias cc {    
    puts "incr_compile $ns::WORK_LIB [concat $src_rtl $src_tb]"
    incr_compile $ns::WORK_LIB [concat $src_rtl $src_tb]
}

alias sim {
    vsim -gui -t ps -L work lwc_tb
}


# Preparing the library
if {(![file isdirectory $ns::LIB_DIR] || ![file isdirectory $ns::WORK_LIB])} {
    prep_work
}

