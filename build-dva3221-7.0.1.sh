
#!/bin/bash

# prepare build tools
sudo apt-get update && sudo apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod jq

root=`pwd`
mkdir DVA3221-7.0.1
mkdir output
cd DVA3221-7.0.1

# download redpill
git clone -b develop --depth=1 https://github.com/dogodefi/redpill-lkm.git
git clone -b develop --depth=1 https://github.com/dogodefi/redpill-load.git

# download syno toolkit
curl --location "https://global.download.synology.com/download/ToolChain/toolkit/7.0/denverton/ds.denverton-7.0.dev.txz" --output ds.denverton-7.0.dev.txz

mkdir denverton
tar -C./denverton/ -xf ds.denverton-7.0.dev.txz usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build

# build redpill-lkm
cd redpill-lkm
sed -i 's/   -std=gnu89/   -std=gnu89 -fno-pie/' ../denverton/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build/Makefile
make LINUX_SRC=../denverton/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build dev-v7
read -a KVERS <<< "$(sudo modinfo --field=vermagic redpill.ko)" && cp -fv redpill.ko ../redpill-load/ext/rp-lkm/redpill-linux-v${KVERS[0]}.ko || exit 1
cd ..

# build redpill-load
cd redpill-load
cp -f ${root}/user_config.DVA3221.json ./user_config.json
./ext-manager.sh add 'https://github.com/pocopico/redpill-load/raw/develop/redpill-misc/rpext-index.json'
# ./ext-manager.sh add https://raw.githubusercontent.com/pocopico/rp-ext/master/mpt3sas/rpext-index.json
./ext-manager.sh add https://raw.githubusercontent.com/dogodefi/redpill-load/develop/redpill-virtio/rpext-index.json
sudo BRP_JUN_MOD=1 BRP_DEBUG=1  ./build-loader.sh 'DVA3221' '7.0.1-42218'
mv images/redpill-DVA3221_7.0.1-4221*.img ${root}/output/
cd ${root}
