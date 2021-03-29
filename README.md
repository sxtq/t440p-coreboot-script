# this is very experimintal and should not be used yet.
# i have tested it and it does work but im not sure its ready for public use yet
# t440p-coreboot-script
This script will do what is needed to coreboot a t440p with exception of building the coreboot.rom, it will give you the needed files but it wont build the rom yet.

So this script will create a backup of each chip (top and bottom) twice and verify they are correct. it will then extract what is needed from the backup .rom file
after this it will put it all inside a directory called setup and you can use those files to build coreboot.rom. after you build coreboot.rom you can place it back in the setup directory and run the script again. it will then flash the chips after verifying the backups exist.
