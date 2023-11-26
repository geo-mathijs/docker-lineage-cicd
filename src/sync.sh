#!/bin/bash

# Docker build script
# Copyright (c) 2017 Julian Xhokaxhiu
# Copyright (C) 2017-2018 Nicola Corna <nicola@corna.info>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -eEuo pipefail

repo_log="$LOGS_DIR/repo-$(date +%Y%m%d).log"

# cd to working directory
cd "$SRC_DIR"

if [ -f /root/userscripts/begin.sh ]; then
  echo ">> [$(date)] Running begin.sh"
  /root/userscripts/begin.sh || echo ">> [$(date)] Warning: begin.sh failed!"
fi

# If requested, clean the OUT dir in order to avoid clutter
if [ "$CLEAN_OUTDIR" = true ]; then
  echo ">> [$(date)] Cleaning '$ZIP_DIR'"
  rm -rf "${ZIP_DIR:?}/"*
fi

# Treat DEVICE_LIST as DEVICE_LIST_<first_branch>
first_branch=$(cut -d ',' -f 1 <<< "$BRANCH_NAME")
if [ -n "$DEVICE_LIST" ]; then
  device_list_first_branch="DEVICE_LIST_${first_branch//[^[:alnum:]]/_}"
  device_list_first_branch=${device_list_first_branch^^}
  read -r "${device_list_first_branch?}" <<< "$DEVICE_LIST,${!device_list_first_branch:-}"
fi

# If needed, migrate from the old SRC_DIR structure
if [ -d "$SRC_DIR/.repo" ]; then
  branch_dir=$(repo info -o | sed -ne 's/Manifest branch: refs\/heads\///p' | sed 's/[^[:alnum:]]/_/g')
  branch_dir=${branch_dir^^}
  echo ">> [$(date)] WARNING: old source dir detected, moving source from \"\$SRC_DIR\" to \"\$SRC_DIR/$branch_dir\""
  if [ -d "$branch_dir" ] && [ -z "$(ls -A "$branch_dir")" ]; then
    echo ">> [$(date)] ERROR: $branch_dir already exists and is not empty; aborting"
  fi
  mkdir -p "$branch_dir"
  find . -maxdepth 1 ! -name "$branch_dir" ! -path . -exec mv {} "$branch_dir" \;
fi


jobs_arg=()
if [ -n "${PARALLEL_JOBS-}" ]; then
  if [[ "$PARALLEL_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    jobs_arg+=( "-j$PARALLEL_JOBS" )
  else
    echo "PARALLEL_JOBS is not a positive number: $PARALLEL_JOBS"
    exit 1
  fi
fi

for branch in ${BRANCH_NAME//,/ }; do
  branch_dir=${branch//[^[:alnum:]]/_}
  branch_dir=${branch_dir^^}
  device_list_cur_branch="DEVICE_LIST_$branch_dir"
  devices=${!device_list_cur_branch}

  if [ -n "$branch" ] && [ -n "$devices" ]; then
    vendor=lineage
    apps_permissioncontroller_patch=""
    modules_permission_patch=""
    case "$branch" in
      cm-14.1*)
        vendor="cm"
        themuppets_branch="cm-14.1"
        android_version="7.1.2"
        frameworks_base_patch="android_frameworks_base-N.patch"
        ;;
      lineage-15.1*)
        themuppets_branch="lineage-15.1"
        android_version="8.1"
        frameworks_base_patch="android_frameworks_base-O.patch"
        ;;
      lineage-16.0*)
        themuppets_branch="lineage-16.0"
        android_version="9"
        frameworks_base_patch="android_frameworks_base-P.patch"
        ;;
      lineage-17.1*)
        themuppets_branch="lineage-17.1"
        android_version="10"
        frameworks_base_patch="android_frameworks_base-Q.patch"
        ;;
      lineage-18.1*)
        themuppets_branch="lineage-18.1"
        android_version="11"
        frameworks_base_patch="android_frameworks_base-R.patch"
        apps_permissioncontroller_patch="packages_apps_PermissionController-R.patch"
        ;;
      lineage-19.1*)
        themuppets_branch="lineage-19.1"
        android_version="12"
        frameworks_base_patch="android_frameworks_base-S.patch"
        modules_permission_patch="packages_modules_Permission-S.patch"
        ;;
      lineage-20.0*)
        themuppets_branch="lineage-20.0"
        android_version="13"
        frameworks_base_patch="android_frameworks_base-Android13.patch"
        modules_permission_patch="packages_modules_Permission-Android13.patch"
        ;;
      *)
        echo ">> [$(date)] Building branch $branch is not (yet) suppported"
        exit 1
        ;;
      esac

    android_version_major=$(cut -d '.' -f 1 <<< $android_version)

    mkdir -p "$SRC_DIR/$branch_dir"
    cd "$SRC_DIR/$branch_dir"

    echo ">> [$(date)] Branch:  $branch"
    echo ">> [$(date)] Devices: $devices"

    # Remove previous changes of vendor/cm, vendor/lineage and frameworks/base (if they exist)
    # TODO: maybe reset everything using https://source.android.com/setup/develop/repo#forall
    for path in "vendor/cm" "vendor/lineage" "frameworks/base" "packages/apps/PermissionController" "packages/modules/Permission"; do
      if [ -d "$path" ]; then
        cd "$path"
        git reset -q --hard
        git clean -q -fd
        cd "$SRC_DIR/$branch_dir"
      fi
    done

    echo ">> [$(date)] (Re)initializing branch repository" | tee -a "$repo_log"
    if [ "$LOCAL_MIRROR" = true ]; then
      ( yes||: ) | repo init -u https://github.com/LineageOS/android.git --reference "$MIRROR_DIR" -b "$branch" --git-lfs &>> "$repo_log"
    else
      ( yes||: ) | repo init -u https://github.com/LineageOS/android.git -b "$branch" --git-lfs &>> "$repo_log"
    fi

    # Copy local manifests to the appropriate folder in order take them into consideration
    echo ">> [$(date)] Copying '$LMANIFEST_DIR/*.xml' to '.repo/local_manifests/'"
    mkdir -p .repo/local_manifests
    rsync -a --delete --include '*.xml' --exclude '*' "$LMANIFEST_DIR/" .repo/local_manifests/

    rm -f .repo/local_manifests/proprietary.xml
    if [ "$INCLUDE_PROPRIETARY" = true ]; then
      wget -q -O .repo/local_manifests/proprietary.xml "https://raw.githubusercontent.com/TheMuppets/manifests/$themuppets_branch/muppets.xml"
      /root/build_manifest.py --remote "https://gitlab.com" --remotename "gitlab_https" \
        "https://gitlab.com/the-muppets/manifest/raw/$themuppets_branch/muppets.xml" .repo/local_manifests/proprietary_gitlab.xml
    fi

    echo ">> [$(date)] Syncing branch repository" | tee -a "$repo_log"
    builddate=$(date +%Y%m%d)
    repo sync "${jobs_arg[@]}" -c --force-sync &>> "$repo_log"

    if [ ! -d "vendor/$vendor" ]; then
      echo ">> [$(date)] Missing \"vendor/$vendor\", aborting"
      exit 1
    fi
  fi
done
