#
# Create New Empty XPS project for zc706
#
xload new $env(TOP_MODULE)_ps.xmp
#
# Change technology for correct Zync device and board
#
if { $env(TOP_MODULE) == "zc706" } {
    xset arch zynq
    xset dev xc7z045
    xset package ffg900
    xset speedgrade -2
    xset binfo ZC706
} elseif { $env(TOP_MODULE) == "zc702" } {
    xset arch zynq
    xset dev xc7z020
    xset package clg484
    xset speedgrade -1
    xset binfo zc702
} elseif { $env(TOP_MODULE) == "zedboard" } {
    xset arch zynq
    xset dev xc7z020
    xset package clg484
    xset speedgrade -1
    xset binfo zedboard
}

xset hier sub
xset hdl verilog
xset intstyle PA
xset flow ise
#
# Copy over empty .mhs file created at project initialization
# with existing master copy specifying full PS+PL config
#
exec cp $env(XPS_PROJECT_FILES)/$env(TOP_MODULE)_master.mhs $env(TOP_MODULE)_ps.mhs
exec cp $env(XPS_PROJECT_FILES)/ps7_$env(TOP_MODULE)_ps_prj.xml data/ps7_$env(TOP_MODULE)_ps_prj.xml
run resync
#
# Now save everything back to files so that .xmp and make files are updated.
#
save proj
#
# Ruuning DRC causes essential files to be generated that are dependacies for netlist generation
#
#run drc
#
# Run XST to generate ngc netlist files.
#
xset parallel_synthesis yes
run stubgen
#run drc
run netlist

exit
