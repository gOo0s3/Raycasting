# Raycasting
A friend of mine and I built this raycaster in pure x86 TASM assembly.

# Notes
* This program is made for the DOSBox Emulator.
* If you are running this program on a laptop, we recommend charging it while running the program.

# Running the program
1. From this repository, download the files `royale.exe` and `maze.bmp` (or compile and link `royale.asm` yourself)
2. To make sure the program runs smoothly, first run the following command: `cycles max`.
3. Run the program with the simple command: `ROYALE.EXE`.
4. Move around the map using the controls

# Controls
Use the `WASD` keys to move around. Use the mouse (or `J` and `L` keys) to rotate. Press space to go into map mode. Press Escape to exit the program and go back into text mode.

# Compiling and linking the code
* Make sure `royale.asm` is in the same directory as your TASM assembler and TLINK linker.
1. compile the code: `TASM ROYALE.ASM`. This will make an object file called `ROYALE`
2. link: `TLINK ROYALE`.
You will now have an executeable file called `ROYALE.EXE` you can run.
