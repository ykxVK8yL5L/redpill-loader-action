
#!/bin/bash

# choose arch
dsmodel=$1
case $1 in
 DS3622xs+)
        arch="broadwellnk"
        osid="ds3622xsp"
        echo "arch is Broadwellnk"
        ;;
 RS4021xs+)
        arch="broadwellnk"
        osid="ds4021xsp"
        echo "arch is Broadwellnk"
        ;;
 DVA3221)
        arch="denverton"
        osid="dva3221"
        echo "arch is Denverton"
        ;;
 DS918+)
        arch="apollolake"
        osid="ds918p"
        echo "arch is Apollolake"
        ;;
  DS3615xs)
        arch="bromolow"
        osid="ds3615xs"
        echo "arch is Bromolow"
        ;;
  DS3617xs)
        arch="broadwellnk"
        osid="ds3617xs"
        echo "arch is Bromolow"
        ;;
 DS920+)
        arch="geminilake"
        osid="ds920p"
        echo "arch is Geminilake"
        ;;
 *)
        echo "Usage: $dsmodel [DS3622xs+|RS4021xs+|DVA3221|DS918+|DS920+|DS3615xs]"
        exit 1
        ;;
esac



# prepare build tools
sudo apt-get update && sudo apt-get install --yes --no-install-recommends ca-certificates build-essential git libssl-dev curl cpio bspatch vim gettext bc bison flex dosfstools kmod jq
root=`pwd`
os_version=$2
pat_address="https://global.download.synology.com/download/DSM/release/7.1/"${os_version}"/DSM_"${dsmodel}"_"${os_version}".pat"
echo ${pat_address}
#https://global.download.synology.com/download/DSM/release/7.1/42621/DSM_DS3622xs%2B_42621.pat

workpath=${arch}"-7.1.0"
mkdir $workpath
build_para="7.1.0-"${os_version}
mkdir output
cd $workpath


# download redpill
git clone -b master --depth=1 https://github.com/pocopico/redpill-lkm.git
git clone -b master --depth=1 https://github.com/pocopico/redpill-load.git

# download syno toolkit
curl --location "https://global.download.synology.com/download/ToolChain/toolkit/7.0/"${arch}"/ds."${arch}"-7.0.dev.txz" --output ds.${arch}-7.0.dev.txz

mkdir ${arch}
tar -C./${arch}/ -xf ds.${arch}-7.0.dev.txz usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build

# build redpill-lkm
cd redpill-lkm
sed -i 's/   -std=gnu89/   -std=gnu89 -fno-pie/' ../${arch}/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build/Makefile
make LINUX_SRC=../${arch}/usr/local/x86_64-pc-linux-gnu/x86_64-pc-linux-gnu/sys-root/usr/lib/modules/DSM-7.0/build dev-v7
read -a KVERS <<< "$(sudo modinfo --field=vermagic redpill.ko)" && cp -fv redpill.ko ../redpill-load/ext/rp-lkm/redpill-linux-v${KVERS[0]}.ko || exit 1
cd ..

# download old pat for syno_extract_system_patch # thanks for jumkey's idea.
mkdir synoesp
curl --location https://global.download.synology.com/download/DSM/release/7.0.1/42218/DSM_DS3622xs%2B_42218.pat --output oldpat.tar.gz
tar -C./synoesp/ -xf oldpat.tar.gz rd.gz
cd synoesp

output=$(xz -dc < rd.gz 2>/dev/null | cpio -idm 2>&1)
mkdir extract && cd extract
cp ../usr/lib/libcurl.so.4 ../usr/lib/libmbedcrypto.so.5 ../usr/lib/libmbedtls.so.13 ../usr/lib/libmbedx509.so.1 ../usr/lib/libmsgpackc.so.2 ../usr/lib/libsodium.so ../usr/lib/libsynocodesign-ng-virtual-junior-wins.so.7 ../usr/syno/bin/scemd ./
ln -s scemd syno_extract_system_patch

curl --location  ${pat_address} --output ${os_version}.pat

sudo LD_LIBRARY_PATH=. ./syno_extract_system_patch ${os_version}.pat output-pat

cd output-pat && sudo tar -zcvf ${os_version}.pat * && sudo chmod 777 ${os_version}.pat
read -a os_sha256 <<< $(sha256sum ${os_version}.pat)
echo $os_sha256
cp ${os_version}.pat ${root}/${workpath}/redpill-load/cache/${osid}_${os_version}.pat
cd ../../../


# build redpill-load
cd redpill-load
cp -f ${root}/user_config.${dsmodel}.json ./user_config.json
sed -i '0,/"sha256.*/s//"sha256": "'$os_sha256'"/' ./config/${dsmodel}/${build_para}/config.json
cat ./config/${dsmodel}/${build_para}/config.json

# 7.1.0 must add this ext
./ext-manager.sh add https://raw.githubusercontent.com/pocopico/redpill-load/master/redpill-misc/rpext-index.json
./ext-manager.sh add https://raw.githubusercontent.com/pocopico/rp-ext/main/e1000/rpext-index.json
# add optional ext
#./ext-manager.sh add https://raw.githubusercontent.com/dogodefi/mpt3sas/offical/rpext-index.json
#./ext-manager.sh add https://raw.githubusercontent.com/jumkey/redpill-load/develop/redpill-virtio/rpext-index.json
#./ext-manager.sh add https://raw.githubusercontent.com/dogodefi/redpill-ext/master/acpid/rpext-index.json
# ./ext-manager.sh add https://raw.githubusercontent.com/dogodefi/mpt3sas/offical/rpext-index.json
# ./ext-manager.sh add https://raw.githubusercontent.com/jumkey/redpill-load/develop/redpill-virtio/rpext-index.json
sudo ./build-loader.sh ${dsmodel} '7.1.0-'${os_version}
mv images/redpill-${dsmodel}*.img ${root}/output/
cd ${root}
