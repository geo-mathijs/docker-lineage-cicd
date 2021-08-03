#!/bin/bash

# FILE: /root/userscripts/before.sh
#
# The original userscripts mount path (pre-copy) should contain our system_dump mounts

pushd /root/userscripts

branch_dir=$(sed 's/[^[:alnum:]]/_/g' <<< "$BRANCH_NAME")
branch_dir=${branch_dir^^}

cd $SRC_DIR/$branch_dir/device/fairphone/FP3
./extract-files.sh /srv/userscripts/system_dump/

echo ">> [$(date)] Finished extracting blobs"

popd

