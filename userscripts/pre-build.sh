#!/bin/bash

# FILE: /root/userscripts/pre-build.sh
#
# The original userscripts mount path (pre-copy) should contain our system_dump mounts.
# Also mount the system folder to /system with docker to keep the symlinks alive

pushd /root/userscripts

branch_dir=$(sed 's/[^[:alnum:]]/_/g' <<< "$BRANCH_NAME")
branch_dir=${branch_dir^^}

cd $SRC_DIR/$branch_dir/device/fairphone/FP3
./extract-files.sh /system

echo ">> [$(date)] Finished extracting blobs"

popd

