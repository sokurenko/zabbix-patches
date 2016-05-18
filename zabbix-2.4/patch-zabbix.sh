#!/bin/bash

# shows patch selection, applies the selected patches
# no error checking at all
# no conflict/dependency concept

command -v dialog 2>&1 || { echo >&2 "This script requires 'dialog'. Please install it!"; exit 1; }

[[ "$@" ]] || {
    echo "Usage:
$0 zabbix_version target_directory

Example:
$0 2.4.8 /path/to/frontend"
    exit
}

zabbix_version=$1
zabbix_major_version=${zabbix_version%.*}
target_dir=$2

[[ -d $target_dir ]] || {
    echo "target directory \"$target_dir\" does not exist"
    exit 1
}

[[ $target_dir =~ /$ ]] || target_dir=$target_dir/

while IFS='|' read patch_id type details; do

    [[ $type = name ]] && {
        patch_name["$patch_id"]=$details
        continue
    }
    [[ $type = f ]] && {
        patch_frontend_only["$patch_id"]=$details
        continue
    }
    [[ $type = desc ]] && {
        patch_desc["$patch_id"]=$details
        continue
    }
    # patch directory levels to remove
    [[ $type = ltr ]] && {
        patch_ltr["$patch_id"]=$details
        continue
    }
    [[ $type = extra ]] && {
        patch_extra["$patch_id"]="${patch_extra[$patch_id]#$'\n'}"$'\n'"$details"
        continue
    }
done < <(tail -n +2 patches.def)

for ((patchid=1; patchid<${#patch_name[@]}+1; patchid++)); do
    patchlist+=($patchid "${patch_name[$patchid]#zabbix-$zabbix_major_version-} ${patch_desc[$patchid]}" off)
done

patches=$(dialog --stdout --checklist "Choose the patches to apply" 0 0 0 "${patchlist[@]}")

[[ $patches ]] || {
    echo
    echo "No patches selected"
    exit
}

for patch in $patches; do
    cp ${patch_name[$patch]}/${patch_name[$patch]}.patch $target_dir/${patch_frontend_only["$patch"]:+frontends/php}
    cd $target_dir/${patch_frontend_only["$patch"]:+frontends/php}
    patch -p ${patch_ltr["$patch"]:-0} -i ${patch_name[$patch]}.patch
    cd -
    while read extra; do
        cp $extra
    done < <(echo "${patch_extra[$patch]}" | sed -e "s| | $target_dir/${patch_frontend_only["$patch"]:+frontends/php/}|" -e "s|^|${patch_name[$patch]}/${patch_name[$patch]}-|")
done
