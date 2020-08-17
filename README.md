# DryGASCON-LWC-API
Hardware implementation of [DryGASCON](https://github.com/sebastien-riou/DryGASCON)128 compliant with [Lightweight Cryptography](https://csrc.nist.gov/projects/lightweight-cryptography) (LWC) [hardware API](https://cryptography.gmu.edu/athena/index.php?id=LWC).


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
- If "wave.do" is presented in the directory, user doesn't need to manually add the waveform. Note: "wave.do" can be clicking at the waveform windows select: File->"Save Format..."
