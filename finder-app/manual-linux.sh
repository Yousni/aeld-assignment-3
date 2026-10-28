#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

#set toolchain path if not already set in the PATH
TOOLCHAIN_BIN="/home/yousnim/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu/bin"
export PATH="$PATH:$TOOLCHAIN_BIN"

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} Image
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs/{var/log,bin,sbin,etc,proc,sys,dev,usr/bin,usr/sbin,usr/lib,home,home/conf,tmp,root,lib,lib64}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "Library dependencies"
# TODO: Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
INTERPRETER=$(${CROSS_COMPILE}readelf -l busybox | sed -n 's/.*interpreter: \(.*\)]/\1/p')

# Add BusyBox's ELF interpreter and shared libraries to the rootfs.
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
DEST_INTER="${OUTDIR}/rootfs/lib"
mkdir -p "$DEST_INTER"

DEST_SHARED_LIB="${OUTDIR}/rootfs/lib64"
mkdir -p "$DEST_SHARED_LIB"

INTERPRETER=$(
    ${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox |
        sed -n 's/.*interpreter: \(.*\)]/\1/p'
)

if [ -n "$INTERPRETER" ]; then
    if [ ! -f "${SYSROOT}${INTERPRETER}" ]; then
        echo "Interpreter not found in sysroot: ${SYSROOT}${INTERPRETER}" >&2
        exit 1
    fi
    cp -L "${SYSROOT}${INTERPRETER}" "$DEST_INTER/"
fi

${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox |
    sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p' |
    while IFS= read -r LIBRARY; do
        LIBRARY_PATH=$(find "$SYSROOT" -name "$LIBRARY" -print -quit)

        if [ -z "$LIBRARY_PATH" ]; then
            echo "Library not found in sysroot: $LIBRARY" >&2
            exit 1
        fi

        cp -L "$LIBRARY_PATH" "$DEST_SHARED_LIB"
    done


# TODO: Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/console c 5 1
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3

# TODO: Clean and build the writer utility
make -C ${FINDER_APP_DIR} clean
make -C ${FINDER_APP_DIR} CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
sudo cp ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/writer
sudo cp ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/
sudo cp ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
sudo sed 's|cat ../conf/assignment.txt|cat conf/assignment.txt|' ${FINDER_APP_DIR}/finder-test.sh > ${OUTDIR}/rootfs/home/finder-test.sh
sudo cp ${FINDER_APP_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/conf/username.txt
sudo cp ${FINDER_APP_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/assignment.txt
sudo cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home

# TODO: Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
