#!/bin/bash
set -u
set -e

my_prefix=/opt/helpthehomeless
helpthehomeless_prefix=/opt/helpthehomeless
export NODE_PATH=$helpthehomeless_prefix/lib/node_modules
export NODE_VERSION=v8.9.4
export PKG_CONFIG_PATH=$my_prefix/lib/pkgconfig
mkdir -p $helpthehomeless_prefix

# don't try to reinstall dashd if it's already installed
if [ ! -f /opt/helpthehomeless/bin/helpthehomelessd ]; then
  git clone --depth 1 https://github.com/devilking6105/dashd-installer.git
  pushd dashd-installer
    source install.sh
  popd
else
  echo "It looks like helpthehomelessd is already installed at '/opt/helpthehomeless/bin/helpthehomelessd', that's great!"
fi

export CPPFLAGS="-I$my_prefix/include ${CPPFLAGS:-}"
export CXXFLAGS="$CPPFLAGS"
export LDFLAGS="-L$my_prefix/lib ${LDFLAGS:-}"
export LD_RUN_PATH="$my_prefix/lib:${LD_RUN_PATH:-}"
export PKG_CONFIG_PATH="$my_prefix/lib/pkgconfig"

sudo apt install -y wget curl git python
export PATH=$helpthehomeless_prefix/bin:$PATH
echo $NODE_VERSION > /tmp/NODEJS_VER
curl -fsSL bit.ly/node-installer | bash -s -- --no-dev-deps

git clone --depth 1 https://github.com/devilking6105/dashcore-node $dash_prefix/bitcore -b skip-dash-download

pushd $helpthehomeless_prefix/bitcore
  fallocate -l 2G ./tmp.swap
  mkswap ./tmp.swap
  chmod 0600 ./tmp.swap
  swapon ./tmp.swap

  my_node="$helpthehomeless_prefix/bin/node"
  my_npm="$my_node $helpthehomeless_prefix/bin/npm"
  $my_npm install
  $my_npm install insight-api-dash --S
  #OPTIONAL : If in addition to the API you also might want to have access to the UI explorer, in my exemple I assume you will
  $my_npm install insight-ui-dash --S

  chmod a+x ./bin/bitcore-node-dash
  #LD_LIBRARY_PATH="$my_prefix/lib:${LD_RUN_PATH:-}" $my_node $dash_prefix/bitcore/bin/bitcore-node-dash start -c $helpthehomeless_prefix/

  swapoff ./tmp.swap
  rm ./tmp.swap
popd

sudo rsync -av ./bitcore-node-dash.json $helpthehomeless_prefix/etc/
sudo chown -R helpthehomeless:helpthehomeless $helpthehomeless_prefix/
sudo rsync -av ./dist/etc/systemd/system/dash-insight.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dash-insight
sudo systemctl start dash-insight
