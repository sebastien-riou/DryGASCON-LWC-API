# DryGASCON-GMU
Hardware implementation of DryGASCON128 compliant with GMU hardware API


## ModelSim simulation

- Start ModelSim, typically on Linux this is done by invoking `vsim`.

- Inside ModelSim, you can do the following in the console:

````
cd $REPO/drygascon/script
source modelsim.tcl
uu
r
````

---

Note: 
uu and r are cmd alias

---

- Then Simulate->Run->Run-all for example.
- To get waveforms: View->wave opens a waveform window. Select signals in the main window and add then using right click. Then the simulator can be controlled from the waveform window.