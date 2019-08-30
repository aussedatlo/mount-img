#!/bin/bash

RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

set -e;

helpFunction()
{
   echo ""
   echo "Usage: $0 [options] <file>"
   echo ""
   echo "Options:"
   echo -e "-m \t\t\tMounting mode"
   echo -e "-u \t\t\tUnmounting mode"
   echo -e "-i \t\t\tInformation of the disk"
   echo -e "-d <dir_to_mount> \tDirectory to mount (default /media)"
   echo -e "-h \t\t\tPrint this help"
   exit 1 # Exit script after printing help
}

infoFunction()
{
   print_info "file: $1"

   # check losetup with images
   losetup_list=$(losetup --list -O name,back-file \
      | grep $1 \
      | cut -d " " -f1)
   if [ -z "$losetup_list" ]
   then
      print_info "no losetup found"
   else
      for loop in $losetup_list
      do
         print_info "loop $loop found for this image"
         mounted=$(mount | grep $loop | cut -d " " -f3)
         if [ -z "$mounted" ]
         then
            print_info "not mounted"
         else
            print_info "mounted on $mounted"
         fi
      done
   fi
   exit 0 # Exit script after printing information
}

print_error()
{
   echo -e "[${RED}ERROR${NC}]: $1"
}

print_info()
{
   echo -e "[${GREEN}INFO${NC}]: $1"
}

get_nbr_partition()
{
   nbr_partition=$(fdisk -lu $1 \
      | grep $1 \
      | sed -e "s/*/ /g" \
      | awk '{print $2}' \
      | wc -l)
   echo $(($nbr_partition -1))
}

get_sector_bytes()
{
   echo $(fdisk -lu $1 | grep Units | cut -d= -f2 | cut -d " " -f2)
}

get_loop()
{
   echo $(losetup --list | grep $1 | awk '{print $1}')
}

# $1 : file
# $2 : partition
get_start()
{
   echo $(fdisk -lu $1 \
      | grep $1""$2 \
      | sed -e "s/*/ /g" \
      | awk '{print $2}')
}

# $1 : file
# $2 : partition
get_partition_type()
{
   echo $(fdisk -lu $1 \
      | grep $1""$2 \
      | sed -e "s/*/ /g" \
      | awk '{print $6 $7}')
}

# $1 : loop
get_label_from_loop()
{
   loop=$(echo $1 | cut -c6-12)
   echo $(lsblk -o name,label \
      | grep $loop \
      | awk '{print $2}')
}

# $1 : file
# $2 : path
mount_partition_loop()
{
   sector_bytes=$(get_sector_bytes $1)
   number_partitions=$(get_nbr_partition $1)

   print_info "number partition: "$number_partitions

   if [ $number_partitions -le 0 ]
   then
      print_error "no partition found"
      exit 1
   fi

   # if <directory>/image folder exist, skip
   # the user probably mount it here
   if [ -d "$2"/"$1" ]
   then
      print_error "Folder $2"/"$1 exist, already mounted ?"
      infoFunction $1
   else
      for (( i=1; i<=$number_partitions; i++ ))
      do
         if [ "$(get_partition_type $1 $i)" == "Linuxfilesystem" ] \
         || [ "$(get_partition_type $1 $i)" == "83Linux" ]
         then
            # print_info "Linux filesystem detected"
            start=$(get_start $1 $i)
            index=$(($sector_bytes * $start))
            loop=$(losetup -o $index --partscan --show --find $file)
            label=$(get_label_from_loop $loop)
            if [ -z "$label" ]
            then
               print_info "label not found, using partition$i"
               label="partition$i"
            else
               print_info "partition $label detected"
            fi
            print_info "$label: mounting on "$2"/"$1"/"$label
            mkdir -p $2"/"$1"/"$label
            mount $loop $2"/"$1"/"$label
         else
            print_error "Not a Linux Filesystem, skip this partition"
            print_error $(get_partition_type $1 $i)
         fi
      done
   fi
}

# $1 : file
# $2 : path
umount_partition_loop()
{
   for loop in $(get_loop $1)
   do
      print_info "umounting $loop"
      umount $loop
      losetup -D $loop
   done
   rm -rf $2"/"$1
   print_info "umount done"
}

# MAIN

if [ "$EUID" -ne 0 ]
  then print_error "Please run as root"
  exit 1
fi

while getopts "ihmuf:d:" opt
do
   case "$opt" in
      h ) helpFunction ;;
      i ) info="1" ;;
      m ) mount="1" ;;
      u ) umount="1" ;;
      d ) path="$OPTARG" ;;
      ? ) helpFunction ;;  # Print helpFunction in case
      # parameter is non-existent
   esac
done
shift "$((OPTIND-1))"

file=$1

if [ ! -z "$info" ]
then
   if [ -z "$file" ]
   then
      print_error "file required"
   fi
   infoFunction $file
fi

if [ -z "$mount" ] && [ -z "$umount" ]
then
   print_error "You need one mode to execute this script"
   helpFunction
   exit 1
fi

if [ ! -z "$mount" ] && [ ! -z "$umount" ]
then
   print_error "You can't use mount option with umount option"
   helpFunction
   exit 1
else
   if [ -z "$mount" ]
   then
      mode="umount"
   else
      mode="mount"
   fi
fi

# Print helpFunction in case parameters are empty
if [ -z "$mode" ] || [ -z "$file" ]
then
   print_error "Some parameters are empty..";
   helpFunction
fi

# Default path
if [ -z "$path" ]
then
   path=/media
   directory=$path/$file
fi

# File exist
if [ ! -f "$file" ]
then
   print_error "file $file not found"
   exit 1
fi

if [ "$mode" == "mount" ]
then
   mount_partition_loop $file $path
   exit 0
elif [ "$mode" == "umount" ]
then
   umount_partition_loop $file $path
   exit 0
fi