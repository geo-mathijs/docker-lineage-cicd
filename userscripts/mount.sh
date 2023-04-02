#!/bin/bash

BRANCH_NAME="lineage-20.0"
SRC_DIR="../src/"

src_dir=$(realpath $SRC_DIR)
branch_dir=$(sed 's/[^[:alnum:]]/_/g' <<< "$BRANCH_NAME")
branch_dir=${branch_dir^^}

mkdir system_dump
pushd system_dump

LATEST_BUILD=$(curl https://download.lineageos.org/api/v1/FP3/nightly/changelog | jq -r '.response | map(select(.version == "20.0")) | sort_by(.datetime) | reverse | .[0].url')
curl -L $LATEST_BUILD -o lineage.zip

unzip lineage.zip payload.bin && rm lineage.zip

python $src_dir/$branch_dir/lineage/scripts/update-payload-extractor/extract.py payload.bin --output_dir ./

mkdir system/
sudo mount -o ro system.img system/
sudo mount -o ro vendor.img system/vendor/

echo ">> [$(date)] Mounted prop files (don't forget to unmount later..)"
echo ">> [$(date)] Ready for build"

popd

