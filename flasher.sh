#!/bin/bash

chiptop=W25Q32
chipbot=W25Q64
current_dir=$(printf "%q\n" "$(pwd)")

while test "$#" -gt 0; do
  case "$1" in
    -h|--help)
      echo "  -h, --help                   show list of startup flags"
      echo "  -r, --restore                This will restore the original bios back to the chips"
      exit 0
      ;;
    -r|--restore)
      shift
      echo "Restoreing to original bios"
      export restore=1
      shift
      ;;
  esac
done

#Used for printing text on the screen
print () {
  no_color='\033[0m'
  if [ "$2" = "green" ]; then     #Print Green
    color='\033[1;32m'
  elif [ "$2" = "yellow" ]; then  #Print Yellow
    color='\033[1;33m'
  elif [ "$2" = "red" ]; then     #Print Red
    color='\033[1;31m'
  fi
  echo -e "${color}$1${no_color}" #Takes message and color and prints to screen
}

flash () {
  if [ -f "$current_dir/setup/coreboot.rom" ] && [ ! -f "$current_dir/setup/bottom.rom" ] || [ ! -f "$current_dir/setup/top.rom" ]; then
    read -r -p "Would you like to use $current_dir/setup/coreboot.rom? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      read -r -p "Please enter the full path to coreboot.rom [/path/to/coreboot.rom]: " path_to_rom
    else
      path_to_rom="$current_dir/setup/coreboot.rom"
    fi
  elif [ ! -f "$current_dir/setup/coreboot.rom" ] && [ ! -f "$current_dir/setup/bottom.rom" ] || [ ! -f "$current_dir/setup/top.rom" ]; then
    read -r -p "Please enter the full path to coreboot.rom [/path/to/coreboot.rom]: " path_to_rom
  fi
  if [ ! -f "$current_dir/setup/bottom.rom" ] || [ ! -f "$current_dir/setup/top.rom" ]; then
    if [ -z "$path_to_rom" ]; then
      print "No path specified and missing top/bottom.rom" red
    else
      dd if="$path_to_rom" of="$current_dir/setup/"bottom.rom bs=1M count=8
      dd if="$path_to_rom" of="$current_dir/setup/"top.rom bs=1M skip=8
    fi
  else
    print "Found top.rom and bottom.rom in setup continuing" green
  fi

  if flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chiptop"; then
    print "DETECTED CHIP $chiptop (TOP)" green
    read -r -p "Would you like to flash the top chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      if [  -f "$current_dir/setup/top.rom" ]; then
        print "Top rom file found in setup folder, flashing..." green
        flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -w "$current_dir/setup/top.rom"
        print "Top is done flashing" green
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        exit 1
      else
        print "Top rom not found in setup folder exiting" red
        exit 1
      fi
    fi
  elif flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chipbot"; then
    print "DETECTED CHIP $chiptop (BOTTOM)" green
    read -r -p "Would you like to flash the bottom chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      if [  -f "$current_dir/setup/bottom.rom" ]; then
        print "Bottom rom file found in setup folder, flashing..." green
        flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -w "$current_dir/setup/bottom.rom"
        print "Bottom is done flashing" green
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        exit 1
      else
        print "Bottom rom not found in setup folder exiting" red
        exit 1
      fi
    fi
  else
    print "No chip was found, make sure the clip is connected" red
    print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
    print "[WARNING] RESEAT THE CLIP AND TRY AGAIN" red
    exit 1
  fi
}

setup () {
    if [ -f "$current_dir/setup/mrc.bin" ] && [  -f "$current_dir/setup/me.bin" ] && [ -f "$current_dir/setup/gbe.bin" ] && [ -f "$current_dir/setup/mrc.bin" ]; then
      print "All files needed found in setup checking for rom files"
      if [ -f "$current_dir/setup/coreboot.rom" ]; then
        print "Coreboot.rom found in setup directory starting flasher" green
        flash
      else
        print "coreboot.rom was not found in the setup directory" red
        print "Please copy coreboot.rom to: $current_dir/setup/" red
        return 0
      fi
    fi
    mkdir -p "$current_dir/setup"
    if [ -f "$current_dir/coreboot" ]; then
      print "coreboot directory found" green
    else
      print "Coreboot directory not found downloading now" yellow
      git clone https://review.coreboot.org/coreboot
    fi
    cd "$current_dir/coreboot" || return
    git submodule update --init --checkout

    cd "$current_dir/coreboot/util/ifdtool" && make
    ./ifdtool -x "$current_dir/backup/original.rom"
    mv -v flashregion_0_flashdescriptor.bin "$current_dir/setup/ifd.bin"
    mv -v flashregion_2_intel_me.bin "$current_dir/setup/me.bin"
    mv -v flashregion_3_gbe.bin "$current_dir/setup/gbe.bin"

    make -C "$current_dir/coreboot/util/cbfstool"
    cd "$current_dir/coreboot/util/chromeos" || return
    ./crosfirmware.sh peppy
    $current_dir/coreboot/util/cbfstool/cbfstool coreboot-*.bin extract -f mrc.bin -n mrc.bin -r RO_SECTION
    mv mrc.bin "$current_dir/setup"
    print "You now need to build coreboot.rom on your own with the files found in setup" green
    print "Once you have coreboot.rom place it in the setup directory and run this script again" yellow
}

combiner () {
  if [ !  -f "$current_dir/backup/original.rom" ] && [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    cat "$current_dir/backup/8mb_backup1.bin" "$current_dir/backup/4mb_backup1.bin" > "$current_dir/backup/original.rom"
    print "Both backups found and combined into original.rom" green
    print "You should make a backup of this entire backup directory" yellow
    setup
  elif [  -f "$current_dir/backup/original.rom" ]; then
    print "original.rom was found" green
    setup
  elif [ !  -f "$current_dir/backup/original.rom" ] && [ ! -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Bottom backup is needed to complete the install" red
  elif [ !  -f "$current_dir/backup/original.rom" ] && [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ ! -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Top backup is needed to complete the install" red
  fi
}

backup () {
  if [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Backups found continuing" green
    return 0
  fi
  mkdir -p "$current_dir/backup"
  if flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chiptop"; then
    print "DETECTED CHIP $chiptop (TOP)" green
    if [  -f backup/4mb_backup1.bin ]; then
      print "Top backup file found in backup folder nothing to do on this chip" red
      print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
      return 0
    fi
    read -r -p "Would you like to backup the top chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      print "Backing up top chip" yellow
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -r 4mb_backup1.bin
      print "First backup done starting second" green
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -r 4mb_backup2.bin
      print "Second backup done comparing backups" green
      if diff 4mb_backup1.bin 4mb_backup2.bin; then
        print "Top backup is good: 4mb_backup1.bin" green
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        mv 4mb_backup1.bin "$current_dir/backup"
      else
        print "Backup does not match" red
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        print "[WARNING] REMOVE OLD BACKUPS AND RESEAT THE CLIP" red
        exit 1
      fi
    fi
  elif flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chipbot"; then
    print "DETECTED CHIP $chiptop (BOTTOM)" green
    if [  -f backup/8mb_backup1.bin ]; then
      print "Bottom backup file found in backup folder nothing to do on this chip" red
      print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
      return 0
    fi
    read -r -p "Would you like to backup the bottom chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      print "Backing up bottom chip" yellow
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -r 8mb_backup1.bin
      print "First backup done starting second" green
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -r 8mb_backup2.bin
      print "Second backup done comparing backups" green
      if diff 8mb_backup1.bin 8mb_backup2.bin; then
        print "Bottom backup is good: 8mb_backup1.bin" green
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        mv 8mb_backup1.bin "$current_dir/backup"
      else
        print "Backup does not match" red
        print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
        print "[WARNING] REMOVE OLD BACKUPS AND RESEAT THE CLIP" red
        exit 1
      fi
    fi
  else
    print "No chip was found" red
    print "[WARNING] POWER OFF THE PI BEFORE REMOVING THE CLIP OFF THE CHIP" red
    print "[WARNING] RESEAT THE CLIP AND TRY AGAIN" red
  fi
}

restoref () {
  print "Restoring from backup" red
  mkdir -p "$current_dir/setup"
  rm -v "$current_dir/setup/top.rom" "$current_dir/setup/bottom.rom"
  if [ -f "$current_dir/backup/original.rom" ]; then
    read -r -p "Would you like to flash using $current_dir/backup/original.rom? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      print "Seperating original.rom into top.rom and bottom.rom" yellow
      dd if="$current_dir/backup/"original.rom of="$current_dir/setup/"bottom.rom bs=1M count=8
      dd if="$current_dir/backup/"original.rom of="$current_dir/setup/"top.rom bs=1M skip=8
      flash
    fi
  fi
}

main () {
  print "THIS SCRIPT IS NOT FOR ACTUAL USE YET, ONLY RUN ON TEST BOARDS" red
  read -r -p "ARE YOU SURE YOU WANT TO CONTINUE? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ] || [ "$output" = '' ]; then
      exit 1
    else
  if [[ $(who am i) =~ \([-a-zA-Z0-9\.]+\)$ ]]; then
    print "SSH detected checking if inside tmux" yellow
    if [ "$TERM" = "screen" ]; then
      print "This script is insdie tmux" green
    else
      print "Not in tmux exiting, this script must be ran in tmux if using ssh" red
      exit 1
    fi
  else
    print "Not using ssh or inside tmux" green
  fi
  if [[ "$EUID" = 0 ]]; then
    print "Script was ran as root" green
  else
    print "Run as root required" red
    exit 1
  fi
  print "Current directory $current_dir" yellow
  print "   Top chip ID: $chiptop" yellow
  print "Bottom chip ID: $chipbot" yellow
  print "Edit the IDs if incorrect inside the script" yellow
  if [ "$restore" = "1" ]; then
    restoref
    exit 1
  fi
  backup
  combiner
fi
}

main
