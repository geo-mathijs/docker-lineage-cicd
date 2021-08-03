#!/bin/bash

BRANCH_NAME="lineage-18.1"
SRC_DIR="../src/"

src_dir=$(realpath $SRC_DIR)
branch_dir=$(sed 's/[^[:alnum:]]/_/g' <<< "$BRANCH_NAME")
branch_dir=${branch_dir^^}

mkdir system_dump
pushd system_dump

LATEST=$(curl https://download.lineageos.org/FP3 | grep "nightly-FP3-signed.zip" | sed "s/.*\/\([0-9]\+\/lineage-[0-9]\+\.1-[0-9]\+-nightly-FP3-signed\.zip\).*/\1/" | sort | tail -n 1)
curl -L "https://mirrorbits.lineageos.org/full/FP3/$LATEST" -o lineage.zip

unzip lineage.zip payload.bin && rm lineage.zip

python $src_dir/$branch_dir/lineage/scripts/update-payload-extractor/extract.py payload.bin --output_dir ./

mkdir system/
sudo mount -o ro system.img system/
sudo mount -o ro vendor.img system/vendor/

echo ">> [$(date)] Mounted prop files (don't forget to unmount later..)"
echo ">> [$(date)] Ready for build"

popd

