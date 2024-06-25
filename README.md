# Raycasting
A friend of mine and me built this raycaster in pure x86 TASM assembly.

# Notes
* This program in made for the DOSBox Emulator.
* If you are using this program on a laptop, we recommend charging it while running the program.

# Running the program
1. From this repository, download the files `royale.exe` and `maze.bmp` (or compile and link `royale.asm` yourself)
2. To make sure the program runs smoothly, run the following command: `cycles max`.
3. Run the program: `ROYALE.EXE`. Use `wasd` to travel around the map.

# Controls
Use WASD to move around and the mouse to look around.
Press space to view where you are in the map.
Press Escape to exit the program and go back into text mode.

# Compiling the code
* Make sure `royale.asm` is in the same directory as your TASM assembler and TLINK linker.
compile: `TASM ROYALE.ASM`.
link: `TLINK ROTALE`.
You will now have an executeable file called `ROYALE.EXE`.
