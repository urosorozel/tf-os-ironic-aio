#!/bin/bash

IP_OFFSET=9
DEPLOY_INTERFACE="iscsi"

for node in $(openstack baremetal node list --provision-state enroll -f value -c UUID);do
	echo "node: $node"
	mac=$(openstack baremetal port list --node $node -f value -c Address)
	echo "mac: $mac"
	macname=${mac//:/_}
	maclast=${mac: -1}
	maclast=$( expr $maclast + $IP_OFFSET)
	openstack baremetal node set --name QEMU_${macname} --deploy-interface=${DEPLOY_INTERFACE} --driver-info ipmi_address=10.200.0.${maclast} $node
	openstack baremetal node manage QEMU_${macname}
	openstack baremetal node provide QEMU_${macname}
done
