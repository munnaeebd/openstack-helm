#!/bin/bash

{{/*
Copyright 2017 The Openstack-Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

set -ex

# configure all bridge mappings defined in config
# /tmp/auto_bridge_add is one line json file: {"br-ex1":"eth1","br-ex2":"eth2"}
for bmap in `sed 's/[{}"]//g' /tmp/auto_bridge_add | tr "," "\n"`
do
  bridge=${bmap%:*}
  iface=${bmap#*:}
  # adding existing bridge would break out the script when -e is set
  set +e
  ip link add name $bridge type bridge
  set -e
  ip link set dev $bridge up
  if [ -n "$iface" ] && [ "$iface" != "null" ]
  then
    ip link set dev $iface  master $bridge
  fi
done

tunnel_interface="{{- .Values.network.interface.tunnel -}}"
if [ -z "${tunnel_interface}" ] ; then
    # search for interface with default routing
    # If there is not default gateway, exit
    tunnel_interface=$(ip -4 route list 0/0 | awk -F 'dev' '{ print $2; exit }' | awk '{ print $1 }') || exit 1
fi

# determine local-ip dynamically based on interface provided but only if tunnel_types is not null
LOCAL_IP=$(ip a s $tunnel_interface | grep 'inet ' | awk '{print $2}' | awk -F "/" '{print $1}')
if [ -z "${LOCAL_IP}" ] ; then
  echo "Var LOCAL_IP is empty"
  exit 1
fi

tee > /tmp/pod-shared/ml2-local-ip.ini << EOF
[vxlan]
local_ip = "${LOCAL_IP}"
EOF
