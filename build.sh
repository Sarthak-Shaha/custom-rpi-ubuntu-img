#!/bin/bash

set -euxo pipefail

# ==============================================================================
# Variables
# ==============================================================================
if [[ -n ${BASH_SOURCE[0]} ]]; then
    script_path="${BASH_SOURCE[0]}"
else
    script_path="$0"
fi

# Path to dir containing this script
script_dir="$(dirname "$(realpath "$script_path")")"

# Path to repo
repo_dir="$script_dir"

# Release note
release_note="$repo_dir/src/scripts/Versions.txt"

# This is where the image will be created
OUTPUT_ROOT=${OUTPUT_ROOT:-${repo_dir}/build}
echo "OUTPUT_ROOT=${OUTPUT_ROOT}"
mkdir -p ${OUTPUT_ROOT}

# Output Rasbian-ubuntu-os image and zip name
#CUSTOM_IMG_FILE="raspi-ubuntu_os_custom_$(date +%Y%m%d).img"
CUSTOM_IMG_FILE="SilabsMatterPi.img"
#IMG_XZ_FILE="$CUSTOM_IMG_FILE.xz"
IMG_ZIP_FILE=$(basename "$CUSTOM_IMG_FILE" .img).zip

# Staging directory where images are copied to for temporary storage
STAGE_DIR=/tmp/raspbian-ubuntu

# Where the raspios image will be mounted
IMAGE_MOUNT_POINT=${OUTPUT_ROOT}/mnt-rpi

# URL for a raspiubuntu image
BASE_IMAGE_URL=${BASE_IMAGE_URL:-"https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz"}

if curl --output /dev/null --silent --head --fail "$BASE_IMAGE_URL"
then
	echo "The downloading image does exist"
else
	echo "The downloading image does not exist"
	exit
fi

# Where to download the raspiubuntu image
TOOLS_HOME=$HOME/.cache/tools

# ==============================================================================
cleanup() {
    set +e

    # Unmount and detach any loop devices
    loop_names=$(losetup -j $STAGE_DIR/raspiubuntuos_base.img --output NAME -n)
    for loop in ${loop_names}; do
        sudo umount -lf "${loop}p2"
        sudo umount -lf "${loop}p1"
        sudo losetup -d "${loop}"
    done

    set -e
}

trap cleanup EXIT

main() {

    # Download base image
    BASE_IMAGE_NAME=$(basename "${BASE_IMAGE_URL}" .img.xz)
    IMAGE_FILE="$BASE_IMAGE_NAME".img
    [ -f "$TOOLS_HOME"/images/"$IMAGE_FILE" ] || {

        # Download image if it doesn't already exist
        [ -d "$TOOLS_HOME"/images ] || mkdir -p "$TOOLS_HOME"/images
        [ -f "$BASE_IMAGE_NAME".img.xz ] || curl -kLO "$BASE_IMAGE_URL"

        # Extract
        (xz -dkv "$BASE_IMAGE_NAME".img.xz &&
        mv -v "$IMAGE_FILE" /tmp)
        
        # Expand OS partition to 16GB
        EXPAND_SIZE=17352
        (cd /tmp &&
            dd if=/dev/zero bs=1048576 count="$EXPAND_SIZE" >> "$IMAGE_FILE" &&
            mv "$IMAGE_FILE" "$TOOLS_HOME"/images/"$IMAGE_FILE")

        (cd docker-rpi-emu/scripts &&
            sudo ./expand.sh "$TOOLS_HOME"/images/"$IMAGE_FILE" "$EXPAND_SIZE")
    }

    IMAGE_FILE="$TOOLS_HOME"/images/"$IMAGE_FILE"

    # Create a staging dir and make a copy of the raspios base image
    [ -d "$STAGE_DIR" ] || mkdir -p "$STAGE_DIR"
    cp -v "$IMAGE_FILE" "$STAGE_DIR"/raspiubuntuos_base.img

    # Mount the base image
    mkdir -p "$IMAGE_MOUNT_POINT"
    chown -R $(whoami): "$IMAGE_MOUNT_POINT"
    ls -alh "$IMAGE_MOUNT_POINT"
    script/mount.sh "$STAGE_DIR"/raspiubuntuos_base.img "$IMAGE_MOUNT_POINT"

    (
        # Setup QEMU
        cd docker-rpi-emu/scripts
        sudo mount --bind /dev/pts "$IMAGE_MOUNT_POINT"/dev/pts
        sudo ./qemu-setup.sh "$IMAGE_MOUNT_POINT"

        # Mount this repo in $IMAGE_MOUNT_POINT
        sudo mkdir "$IMAGE_MOUNT_POINT"/repo
        sudo mount --bind ${repo_dir} "$IMAGE_MOUNT_POINT"/repo

        # Use chroot to run any commands
        # Ex:
        #     sudo chroot "${IMAGE_MOUNT_POINT}" /bin/bash whoami
        case $# in
                0)
                        sudo chroot "${IMAGE_MOUNT_POINT}" /bin/bash /repo/src/customizeImage.sh
                        shift
                        ;;
                1)
                        sudo chroot "${IMAGE_MOUNT_POINT}" /bin/bash /repo/src/customizeImage.sh "$1"
                        shift
                        ;;
                2)
                        sudo chroot "${IMAGE_MOUNT_POINT}" /bin/bash /repo/src/customizeImage.sh "$1" "$2"
                        shift
                        ;;
                3)
                        sudo chroot "${IMAGE_MOUNT_POINT}" /bin/bash /repo/src/customizeImage.sh "$1" "$2" "$3"
                        shift
                        ;;
                *)
                        echo "Never happen."
        esac

        # Tear down QEMU and create new .img file
        sync && sleep 20
        sudo ./qemu-cleanup.sh "$IMAGE_MOUNT_POINT"
        LOOP_NAME=$(losetup -j $STAGE_DIR/raspiubuntuos_base.img --output NAME -n)
        sudo sh -c "dcfldd of=$STAGE_DIR/$CUSTOM_IMG_FILE if=$LOOP_NAME bs=1m && sync"

        # Attempt to shrink image
        #sudo cp "$STAGE_DIR/$CUSTOM_IMG_FILE" "$STAGE_DIR/${CUSTOM_IMG_FILE}_backup.img"
        if [[ ! -f /usr/bin/pishrink.sh ]]; then
            sudo wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh -O /usr/bin/pishrink.sh && sudo chmod a+x /usr/bin/pishrink.sh
        fi
        set +e
        sudo /usr/bin/pishrink.sh $STAGE_DIR/$CUSTOM_IMG_FILE
        retVal=$?

        # Ignore error when pishrink can't shrink the image any further
        if [[ $retVal -ne 11 ]] && [[ $retVal -ne 0 ]]; then
            exit $retval
        fi
        set -e

	# Copy release note to STAGE_DIR
	cp $release_note $STAGE_DIR
	
        # Zip image file
        (cd $STAGE_DIR && zip -v "$OUTPUT_ROOT/$IMG_ZIP_FILE" $CUSTOM_IMG_FILE Versions.txt)
        #(cd $STAGE_DIR && sudo xz $CUSTOM_IMG_FILE && mv "$IMG_XZ_FILE" "$OUTPUT_ROOT")
    )
}
main "$@"
