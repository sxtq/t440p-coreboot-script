#!/bin/bash

chiptop=W25Q32
chipbot=W25Q64

current_dir=/home/six/t4

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
  if [ -f "$current_dir/setup/coreboot.rom" ] && [ ! -f "$current_dir/setup/bottom.rom" ] && [ ! -f "$current_dir/setup/top.rom" ]; then
    dd if="$current_dir/setup/"coreboot.rom of="$current_dir/setup/"bottom.rom bs=1M count=8
    dd if="$current_dir/setup/"coreboot.rom of="$current_dir/setup/"top.rom bs=1M skip=8
  fi
  if flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chiptop"; then
    print "DETECTED CHIP $chiptop" green
    read -r -p "Would you like to flash the top chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      if [  -f "$current_dir/setup/top.rom" ]; then
        echo "Top rom file found in setup folder starting flasher"
        flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -w "$current_dir/setup/top.rom"
        print "Bottom is done flashing" green
        return 0
      else
        echo "Top rom not found in setup folder exiting"
        exit 1
      fi
    fi
  elif flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 | grep "$chipbot"; then
    print "DETECTED CHIP $chiptop" green
    read -r -p "Would you like to flash the bottom chip? [Y/n]: " output
    if [ "$output" = 'N' ] || [ "$output" = 'n' ]; then
      exit 1
    else
      if [  -f "$current_dir/setup/bottom.rom" ]; then
        echo "Bottom rom file found in setup folder starting flasher"
        flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=512 -w "$current_dir/setup/bottom.rom"
        print "Bottom is done flashing" green
        return 0
      else
        print "Bottom rom not found in setup folder exiting" red
        exit 1
      fi
    fi
  else
    print "No chip was found" red
    exit 1
  fi
}

setup () {
    if [ -f "$current_dir/setup/mrc.bin" ] && [  -f "$current_dir/setup/me.bin" ] && [ -f "$current_dir/setup/gbe.bin" ] && [ -f "$current_dir/setup/mrc.bin" ]; then
      print "All files needed found in setup checking for rom files"
      if [ -f "$current_dir/setup/top.rom" ] && [ -f "$current_dir/setup/bottom.rom" ]; then
        print "Top.rom and bottom.rom found in setup directory starting flasher" green
        flash
      else
        print "coreboot.rom was not found in the setup directory please copy it to..." red
        print "$current_dir/setup/" red
      fi
    fi
    mkdir "$current_dir/setup"
    if [ -f "$current_dir/coreboot" ]; then
      print "coreboot directory found" green
    else
      print "Coreboot directory not found downloading now" yellow
      git clone https://review.coreboot.org/coreboot
    fi
    cd "$current_dir/coreboot" || return
    git submodule update --init --checkout

    cd "$current_dir/coreboot/util/ifdtool" && make
    ./ifdtool -x "$current_dir/backup/t440p-original.rom"
    mv flashregion_0_flashdescriptor.bin "$current_dir/setup/ifd.bin"
    mv flashregion_2_intel_me.bin "$current_dir/setup/me.bin"
    mv flashregion_3_gbe.bin "$current_dir/setup/gbe.bin"

    make -C "$current_dir/coreboot/util/cbfstool"
    cd "$current_dir/coreboot/util/chromeos" || return
    ./crosfirmware.sh peppy
    $current_dir/coreboot/util/cbfstool/cbfstool coreboot-*.bin extract -f mrc.bin -n mrc.bin -r RO_SECTION
    mv mrc.bin "$current_dir/setup"
    print "You now need to build coreboot.rom on your own with the files found in setup" green
    print "Once you have coreboot.rom place it in the setup directory and run this script again" yellow
}

combiner () {
  if [ !  -f "$current_dir/backup/t440p-original.rom" ] && [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    cat "$current_dir/backup/8mb_backup1.bin" "$current_dir/backup/4mb_backup1.bin" > "$current_dir/backup/t440p-original.rom"
    print "Both backups found and combined into t440p-original.rom" green
    setup
  elif [  -f "$current_dir/backup/t440p-original.rom" ]; then
    print "t440p-original.rom was found" green
  elif [ !  -f "$current_dir/backup/t440p-original.rom" ] && [ ! -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Bottom backup is needed to complete the install" red
  elif [ !  -f "$current_dir/backup/t440p-original.rom" ] && [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ ! -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Top backup is needed to complete the install" red
  fi
}

backup () {
  if [ -f "$current_dir/backup/8mb_backup1.bin" ] && [ -f "$current_dir/backup/4mb_backup1.bin" ]; then
    print "Backups found continuing" green
    return 0
  fi
  mkdir "$current_dir/backup"
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
    print "Not using ssh tmux not required" green
  fi
  if [[ "$EUID" = 0 ]]; then
    print "Ran as root check" green
  else
    print "Run as root required" red
    exit 1
  fi
  if [ -f "$current_dir/setup/coreboot.rom" ]; then
    print "Coreboot.rom found in setup directory starting flasher" yellow
    flash
  fi
  backup
  combiner
fi
}

main

