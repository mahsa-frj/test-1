#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
set -o xtrace
set -o errexit

# install_dependencies() - Install required dependencies
function install_dependencies {
    apt-get update
    apt-get install -y -qq wget openjdk-8-jre bridge-utils net-tools bsdmainutils unzip
}

# install_vpp() - Install VPP
function install_vpp {
    local RELEASE=".stable.1609"
    apt-get update
    apt-get install -y -qq apt-transport-https
    echo "deb [trusted=yes] https://packagecloud.io/fdio/release/ubuntu xenial main" | tee /etc/apt/sources.list.d/99fd.io.list
    curl -L https://packagecloud.io/fdio/release/gpgkey | apt-key add - 
    apt-get update
    apt-get install -y -qq --no-install-recommends vpp
    mkdir -p /var/log/vpp/
    rm -rf /var/lib/apt/lists/*
}

function _untar_url {
    local repo_url="https://nexus.onap.org/content/repositories/releases/org/onap/demo/vnf"
    local file_subpath=$1

    wget -q -O tmp_file.tar.gz "${repo_url}/${file_subpath}"
    sha1=$(wget ${repo_url}/${file_subpath}.sha1 -q -O -)
    if [[ $(sha1sum tmp_file.tar.gz  | awk '{print $1}') != "$sha1" ]]; then
        echo "The downloaded file is corrupted"
        exit 1
    fi
    tar -zmxf tmp_file.tar.gz
    rm tmp_file.tar.gz
}

# install_vfw_scripts() -
function install_vfw_scripts {

    pushd /opt
    wget -q "https://nexus.onap.org/content/repositories/releases/org/onap/demo/vnf/vfw/vfw-scripts/1.6.0/vfw-scripts-1.6.0.zip"
    unzip "vfw-scripts-1.6.0.zip"
    wget "https://raw.githubusercontent.com/mahsanaru/demo/master/heat/vFW_CNF_CDS/templates/helm/vfw/templates/tap.sh"
    mv tap.sh v_firewall_init.sh
    chmod +x *.sh

    _untar_url "sample-distribution/1.6.0/sample-distribution-1.6.0-hc.tar.gz"
    mv sample-distribution-1.6.0 honeycomb

    _untar_url "vfw/vfw_pg_streams/1.6.0/vfw_pg_streams-1.6.0-demo.tar.gz"
    mv vfw_pg_streams-1.6.0 pg_streams

    sed -i 's/"restconf-binding-address": "127.0.0.1",/"restconf-binding-address": "0.0.0.0",/g' /opt/honeycomb/config/restconf.json

    # TODO(electrocucaracha) Fix it in upstream
    sed -i 's/start vpp/systemctl start vpp/g' v_firewall_init.sh
    sed -i 's|/opt/honeycomb/sample-distribution-1.6.0/honeycomb|/opt/honeycomb/honeycomb|g' v_firewall_init.sh
    mv vfirewall.sh /etc/init.d
    update-rc.d vfirewall.sh defaults
    systemctl start firewall
    popd
}

mkdir -p /opt/config/
echo "$protected_net_cidr"     > /opt/config/protected_net_cidr.txt
echo "$vfw_private_ip_0"       > /opt/config/fw_ipaddr.txt
echo "$vsn_private_ip_0"       > /opt/config/sink_ipaddr.txt
echo "$demo_artifacts_version" > /opt/config/demo_artifacts_version.txt

echo 'vm.nr_hugepages = 1024' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

install_dependencies
install_vpp
install_vfw_scripts


       
