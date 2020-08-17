set ROOT_PATH [file normalize "../.."]
set RTL_PATH [file normalize "../src_rtl"]
set DRYGASCON_PATH [file normalize [subst "$ROOT_PATH/submodules/github/DryGASCON"]]
set LWC_PATH       [file normalize [subst "$ROOT_PATH/submodules/github/LWC"]]
set RUN_TIME "1000 ns"

set src_rtl [subst {
    "$RTL_PATH/birotr.v"
    "$RTL_PATH/mix32.v"
    "$RTL_PATH/gascon_round.v"
    "$RTL_PATH/drygascon.v"
    "$RTL_PATH/design_pkg.vhd"
    "$RTL_PATH/CryptoCore.vhd"
    "$LWC_PATH/hardware/LWCsrc/fwft_fifo.vhd"
    "$LWC_PATH/hardware/LWCsrc/NIST_LWAPI_pkg.vhd"
    "$LWC_PATH/hardware/LWCsrc/key_piso.vhd"
    "$LWC_PATH/hardware/LWCsrc/data_piso.vhd"
    "$LWC_PATH/hardware/LWCsrc/data_sipo.vhd"
    "$LWC_PATH/hardware/LWCsrc/StepDownCountLd.vhd"
    "$LWC_PATH/hardware/LWCsrc/PreProcessor.vhd"
    "$LWC_PATH/hardware/LWCsrc/PostProcessor.vhd"
    "$LWC_PATH/hardware/LWCsrc/std_logic_1164_additions.vhd"
    "$LWC_PATH/hardware/LWCsrc/LWC.vhd"
}]

set src_tb [subst {
    "$LWC_PATH/hardware/LWCsrc/LWC_TB.vhd"
}]

source modelsim_setup.tcl
