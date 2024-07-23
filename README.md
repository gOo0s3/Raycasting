# Raycasting
![ASSEMBLY](https://img.shields.io/badge/TASM-Turbo_Assembly-blue) ![DOSBox](https://img.shields.io/badge/DOSBox-orange)

 Raycaster game engine renderer in pure x86 TASM assembly.

![image](https://github.com/user-attachments/assets/2d030487-b2d9-4639-a28f-c23d8d73898e)


# Notes
* This program is made for the DOSBox Emulator.
* If you are running this program on a laptop, we recommend charging it while running the program.

# Running the program
1. From this repository, download the files `royale.exe` and `maze.bmp` (or compile and link `royale.asm` yourself)
2. To make sure the program runs smoothly, first run the following command: `cycles max`.
3. Run the program with the simple command: `ROYALE.EXE`.
4. Move around the map using the controls

# Controls
- Use the `WASD` keys to move around.
- Press `SPACE` to toggle edit mode.
- Use the mouse (or `J` and `L` keys) to rotate.
- Press `Escape` to exit the program.

# Compiling and linking the code
* Make sure `royale.asm` is in the same directory as your TASM assembler and TLINK linker.
1. compile the code: `TASM ROYALE.ASM`. This will make an object file called `ROYALE`
2. link: `TLINK ROYALE`.
You will now have an executeable file called `ROYALE.EXE` you can run.
