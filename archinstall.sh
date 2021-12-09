#!/bin/bash

## To fix:
## - NVME partition names

## FUNCTIONS
pre_partition() {
  printf "The following disks and partitions are available:\n\n"
  fdisk -l | grep /dev/

  printf "\nDo you want to partition a disk? (DO NOT USE ON A DISK WITH OTHER PARTITIONS!) [y/N] "
  read partition

  if [ $partition == 'y' ]
  then
    partition_disk 
  else
    not_partition
  fi
}

partition_disk() {
  printf "\nSelect the disk to partiton: [e.g. /dev/sda] "    ##
  read disk                                                   ##
  printf "\nConfirm $disk? [y/N] "                            ##
  read diskconfirm                                            ##
  if [ $diskconfirm == 'y' ]                                  ##
  then                                                        ## Disk Selection

    printf "g\nn\n1\n\n+512M\nw" | fdisk $disk                ##
    efipart="${disk}1"                                        ##
    mkfs.fat -F 32 $efipart                                   ## EFI Partition

    printf "\nEnter root partition size: [e.g.: +10G] "       ##
    read rootsize                                             ##
    printf "n\n2\n\n$rootsize\nw" | fdisk $disk               ##
    rootpart="${disk}2"                                       ##
    mkfs.btrfs $rootpart                                      ## Root Partition
    
    printf "\nDo you want a separate Home partition? [Y/n] "  ##
    read separatehome                                         ##
    if [ $separatehome == 'y' ] || [ $separatehome == '' ]    ##
    then                                                      ##
      printf "\nEnter home partition size: [e.g.: +10G] "     ##
      read homesize                                           ##
      printf "n\n3\n\n$homesize\nw" | fdisk $disk             ##
      homepart="${disk}3"                                     ##
      mkfs.btrfs $homepart                                    ##
    fi                                                        ## Home Partition
    
    mount $rootpart /mnt                                      ##
    mkdir /mnt/boot /mnt/boot/grub /mnt/boot/efi /mnt/home    ##
    mount $efipart /mnt/boot/efi                              ##
    if [ $separatehome == 'y' ] || [ $separatehome == '' ]    ##
    then                                                      ##
      mount $homepart /mnt/home                               ## Mount Filesystems
    fi                                                        ##

  else
    printf "\nDo you want to select another disk? [y/N] "
    read newdisk
    if [ $newdisk == 'y' ]
    then
      partition_disk
    else
      exit 0
    fi
  fi

  installations
}

not_partition() {
  
  printf "\nBefore continuing, make sure that the disk is already partitioned and the root partition\
    is mounted in /mnt and the EFI partition in /mnt/boot/efi\n\
    Do you wish to continue? [y/N] "
  read ismounted
  if [ $ismounted == 'y' ]
  then
    installations
  else
    exit 0
  fi

}

installations() {
  base="base linux linux-firmware"
  extra="btrfs-progs sudo networkmanager vi vim ranger xorg-server xorg-xinit xorg-xev grub efibootmgr\
    alacritty zsh git wget base-devel"
  recommended="go pipewire pipewire-pulse pavucontrol helvum firefox rofi nitrogen"
  
  printf "\nDo you want to install OpenBox? [y/N] "
  read obinstall
  if [ $obinstall == 'y' ]
  then
    openbox="openbox obconf tint2"
  else
    openbox=""
    printf "\nOpenBox not installed"
  fi
  
  printf "\nDo you want to install XMonad? [y/N] "
  read xminstall
  if [ $xminstall == 'y' ]
  then
    xmonad="xmonad xmobar"
  else
    xmonad=""
    printf "\nXMonad not installed"
  fi

  printf "\nThe following packages will be installed:\n\
$base $extra $recommended $openbox $xmonad"

  printf "\nIf you wish to install more packages, list them below. Otherwise just press enter.\n\
A typo could result in the system breaking, so make sure the packages are available in the\
standard repository."
  read userinput

  pacstrap /mnt $base $extra $recommended $openbox $xmonad $userinput

  configure
}

configure() {
  genfstab -U /mnt >> /mnt/etc/fstab
  mv ./archinstall.sh /mnt/archinstall.sh
  arch-chroot /mnt /archinstall.sh chroot
}

chrootscript() {
  ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
  printf "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen
  touch /etc/locale.conf && printf "LANG=en_US.UTF-8" >> /etc/locale.conf
  printf "\nEnter hostname: "
  read hostname
  touch /etc/hostname
  printf "$hostname" >> /etc/hostname
  mkinitcpio -P
  printf "\n\n\n"
  passwd
  grubinstall
  systemctl enable NetworkManager.service
  echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

  printf "\nEnter username: "
  read username
  useradd -m $username
  usermod -aG wheel,audio,video $username
  printf "\n\n\n"
  passwd $username
  chsh $username /usr/bin/zsh
  yayinstall "$username"
}

grubinstall() {
  printf "\nEnter GRUB ID (name): "
  read bootid
  grub-mkconfig -o /boot/grub/grub.cfg
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$bootid
}

yayinstall() {
  cd /home/$1
  git clone https://aur.archlinux.org/yay.git
  chown $1 yay
  cd yay
  sudo -u $1 makepkg -si
}

## MAIN
if [ $# -eq 0 ]
then

  printf "
Welcome to my personal Arch Linux installation script.\n\
Before you start, remember that this script is not optimized and may break your current \
installation if you have one.\nI recommend using this script on a new disk.\n\
This script currently doesn't support NVME.\n\
I recommend checking the script before executing.\n\n\
If you don't want to wipe your actual disk, make the required partitions, mount them \
(root in /mnt, EFI in /mnt/boot/efi), then execute the script with \`./archinstall.sh skippart\`.\n\n\
If you wish to continue and wipe the actual disk, run the script with the 'install' argument:\n\
\`./archinstall.sh install\`\n\n"

elif [ $1 == "install" ]
then

  pre_partition

elif [$1 == "skippart"]
then

  not_partition
  
elif [ $1 == "chroot" ]
then

  chrootscript
  printf "\n\n\nFinished! You can now reboot your computer.\n\n"

fi
