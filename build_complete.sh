#!/bin/bash

set -e

if [ ! "$1" ]; then
  echo "usage: build_complete.sh <board_name>"
  exit 1
fi
if [ "$EUID" != "0" ]; then
  echo "error: this script must be run as root"
fi

declare -A special_boards=(
  ["brask"]="mmcblk0 nvme0n1"
  ["brya"]="mmcblk0 nvme0n1"
  ["cherry"]="mmcblk0"
  ["corsola"]="mmcblk0"
  ["guybrush"]="mmcblk0 nvme0n1"
  ["nissa"]="mmcblk0 sda sdb"
  ["rex"]="nvme0n1"
  ["skyrim"]="mmcblk0 nvme0n1"
  ["staryu"]="mmcblk0"
)

board="$1"
base_dir="$(realpath -m $(dirname "$0"))"
data_dir="$base_dir/data"
images_file="$data_dir/images.json"
images_url="https://raw.githubusercontent.com/MercuryWorkshop/chromeos-releases-data/refs/heads/main/data.json"

cd "$base_dir"
mkdir -p "$data_dir"

echo "downloading list of recovery images from https://github.com/MercuryWorkshop/chromeos-releases-data"
if [ ! -f "$images_file" ]; then
  wget -q "$images_url" -O "$images_file"
fi

echo "finding recovery image url"
image_url="$(cat "$images_file" | python3 -c '
import json, sys

images = json.load(sys.stdin)
board_name = sys.argv[1]
board = images[board_name]

for image in reversed(board["images"]):
  major_ver = image["chrome_version"].split(".")[0]
  if not major_ver.isdigit():
    continue
  if image["channel"] != "stable-channel":
    continue
  if int(major_ver) > 124:
    continue
  print(image["url"])
  break
else:
  print(f"error: could not find suitable recovery image for {board_name}", file=sys.stderr)
  sys.exit(1)
' "$board")"
image_zip_name="$(echo "$image_url" | rev | cut -f1 -d'/' | rev)"
image_zip_file="$data_dir/$image_zip_name"
echo "found recovery image url: $image_url"

echo "downloading recovery image"
if [ ! -f "$image_zip_file" ]; then
  if [ "$QUIET" ]; then
    wget -q "$image_url" -O "$image_zip_file"
  else
    wget "$image_url" -O "$image_zip_file"
  fi
fi

echo "extracting recovery image"
image_bin_name="$(unzip -Z1 "$image_zip_file")"
image_bin_file="$data_dir/$image_bin_name"
if [ ! -f "$image_bin_file" ]; then
  unzip -j "$image_zip_file" -d "$data_dir"
fi

image_variants="${special_boards[$board]}"

if [ ! "$image_variants" ]; then
  echo "copying recovery image"
  out_file="$data_dir/badrecovery_$board.bin"
  cp "$image_bin_file" "$out_file"

  echo "building badrecovery"
  ./build_badrecovery.sh -i "$out_file"
  echo "done! the finished image is located at $out_file"

else
  for variant in $image_variants; do
    echo "copying recovery image (internal_disk=$variant)"
    out_file="$data_dir/badrecovery_${board}_${variant}.bin"
    cp "$image_bin_file" "$out_file"

    echo "building badrecovery (internal_disk=$variant)"
    ./build_badrecovery.sh -i "$out_file" --internal_disk="$variant"
    echo "done! the finished image is located at $out_file"
  done
fi