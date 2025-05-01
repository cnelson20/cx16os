[Main page](README.md)

## cx16os build / install guide

If you are just installing cx16os and not trying to build it from source, start [here](#installing-cx16os).

### Building cx16os

Step 1: Clone the github repository using `git clone`.

Step 2: Navigate to the `cx16os/src` directory, then run the `make sd` command.
- If you only want to build cx16os to use on your actual X16 and not try it out on the emulator, you can just run `make` as the SD card image is unnecessary.
- After make is finished running, you should have a `mnt/` directory as well as `cx16os.img` (unless you just ran `make`, and not `make sd`).

Step 3: Rename the newly created `mnt/` folder `OS/`. 

*Note:*
*Make'ing `sd` requires either sudo access on Linux in order to use disk formatting & mounting tools, or on Windows `qemu` installed and admin permissions in order to use `diskpart`.*

*This requires you to run make in a shell started with admin access. I apologize for the inconvience, but I am not aware of any other way to make these disk images Windows, without another dependency.*

<br/>

### Installing cx16os

#### Option 1: X16 Emulator

If you want to try out cx16os on an emulator, it is very simple. x16emu is the only X16 emulator that supports the 65c816, which cx16os requires.

Step 1: Download `cx16os.img` from the latest release [here](https://github.com/cnelson20/cx16os/releases).

Step 2: Run x16emu from the command line in the same directory as the downloaded file with flags `-c816 -ram 2048k -cart roam.crt -sdcard cx16os.img`.

That's it! I also recommend using the `-rtc` flags, since programs like `date` take advantage of the X16's real-time clock.

Several programs written in C also need the ROAM cart in order to access a larger flat address space. If you want to see what happens on real HW when those programs are run without ROAM or an equivalent cartridge is installed, you can remove that flag when launching the emulator. You can also exclude `-ram 2048k`, which lowers the RAM available to the system but won't have a noticeable effect in most use cases.

<br/>

#### Option 2: Real Hardware

Reminder: cx16os requires the 65c816 CPU, which is not standard on the Commander X16 (at time of writing).

Step 1: Make sure you have a 65c816 CPU installed in your X16 by running the `HELP` command in BASIC.

Step 2 (Optional): Install a ROAM or equivalent cartridge in your X16.

Skip step 3 if you built cx16os yourself.

Step 3: Download `cx16os.zip` from the latest release [here](https://github.com/cnelson20/cx16os/releases), and extract the `OS/` folder from the zip archive.

Step 4: Copy the `OS/` folder to the root of your X16's SD card.

- Please do not only copy `OS.PRG` to your SD Card! cx16os will not work without its associated programs, especially `shell`.
- It is not strictly required to copy `OS/` to the root of your SD card. However, when developing, `OS/` is at the root of `cx16os.img`, and bugs that arise if it is not may get overlooked for that reason.
- Poorly written programs not from the cx16os repository may not work if `OS/` is not placed at the root of your SD card as they may be taking advantage of that fact.

Despite all the disclaimers, you have now installed cx16os!

<br/>

### Running cx16os

*Note: the following assumes the `OS/` folder is at the root of your SD card. If you are using the emulator, do not worry about this.*

Step 1: cd to the `OS/` folder using `DOS` or a disk wedge command

- `@CD:OS` is one way to do so

Step 2: Run the `BOOT` command in BASIC.

- If you see a `READY` prompt with a black background in the ISO character set, something went wrong.

Otherwise, you should be placed into cx16os and `shell` will prompt you to enter a command!





