[Main page](README.md)

## cx16os build / install guide

If you are just installing cx16os and not trying to build it from source, start [here](#installing-cx16os)

### Building cx16os

Step 1: Clone the github repository using `git clone`.

Step 2: Navigate to the `cx16os/src` directory, then run the `make sd` command.
- If you only want to build cx16os to use on your actual X16 and not try it out on the emulator, you can just run `make` as the SD card image is unnecessary.

After the makefile is finished, you should have a `mnt/` directory as well as `cx16os.img` (unless you just ran `make`, and not `make sd`).

#### Note: 
Make'ing `sd` requires either sudo access on Linux in order to use disk formatting & mounting tools, and requires admin permissions and qemu installed on Windows in order to use `diskpart`. 

This requires you to run make in a shell started with admin access. I apologize for the inconvience, but I am not aware of any other way to make these disk images Windows, without another dependency.

### Installing cx16os
