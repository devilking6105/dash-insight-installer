#!/bin/bash
set -u
set -e

my_prefix=/opt/dashpay
dash_prefix=/opt/dashpay
export NODE_PATH=$dash_prefix/lib/node_modules
export NODE_VERSION=v8.9.4
export PKG_CONFIG_PATH=$my_prefix/lib/pkgconfig
mkdir -p $dash_prefix

# don't try to reinstall dashd if it's already installed
if [ ! -f /opt/dashpay/bin/dashd ]; then
  git clone --depth 1 https://github.com/devilking6105/dashd-installer.sh.git
  pushd dashd-installer.sh
    source install.sh
  popd
else
  echo "It looks like dashd is already installed at '/opt/dashpay/bin/dashd', that's great!"
fi

export CPPFLAGS="-I$my_prefix/include ${CPPFLAGS:-}"
export CXXFLAGS="$CPPFLAGS"
export LDFLAGS="-L$my_prefix/lib ${LDFLAGS:-}"
export LD_RUN_PATH="$my_prefix/lib:${LD_RUN_PATH:-}"
export PKG_CONFIG_PATH="$my_prefix/lib/pkgconfig"

sudo apt install -y wget curl git python
export PATH=$dash_prefix/bin:$PATH
echo $NODE_VERSION > /tmp/NODEJS_VER
curl -fsSL bit.ly/node-installer | bash -s -- --no-dev-deps

git clone --depth 1 https://github.com/devilking6105/dashcore-node $dash_prefix/bitcore -b skip-dash-download

pushd $dash_prefix/bitcore
  fallocate -l 2G ./tmp.swap
  mkswap ./tmp.swap
  chmod 0600 ./tmp.swap
  swapon ./tmp.swap

  my_node="$dash_prefix/bin/node"
  my_npm="$my_node $dash_prefix/bin/npm"
  $my_npm install
  $my_npm install insight-api-dash --S
  #OPTIONAL : If in addition to the API you also might want to have access to the UI explorer, in my exemple I assume you will
  $my_npm install insight-ui-dash --S

  chmod a+x ./bin/bitcore-node-dash
  #LD_LIBRARY_PATH="$my_prefix/lib:${LD_RUN_PATH:-}" $my_node $dash_prefix/bitcore/bin/bitcore-node-dash start -c $dash_prefix/

  swapoff ./tmp.swap
  rm ./tmp.swap
popd

sudo rsync -av ./bitcore-node-dash.json $dash_prefix/etc/
sudo chown -R dashpay:dashpay $dash_prefix/
sudo rsync -av ./dist/etc/systemd/system/dash-insight.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dash-insight
sudo systemctl start dash-insight
