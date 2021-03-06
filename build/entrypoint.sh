#!/bin/bash

# Parse arguments.
port=6000
OVS_RUNDIR=/var/run/openvswitch

while test $# -gt 0; do
  case "$1" in

    --pci-args)
      pci=$2
      vfs_range=$3
      dpdk_extra="-a ${pci},representor=${vfs_range},dv_flow_en=1,dv_esw_en=0,isolated_mode=1 ${dpdk_extra}"
      shift
      shift
      shift
      ;;

    --pmd-cpu-mask)
      pmd_cpu_mask=$2
      shift
      shift
      ;;

    --port)
      port=$2
      shift
      shift
      ;;

    --help)
      echo "
ovs_container_start.sh [options]: Starting script for ovs container which will configure and start ovs
options:
	--pci-args)	<pci_address> <vfs_range>	A pci address of dpdk interface and range of vfs
							e.g 0000:02:00.0 pf0vf[0-15].
							In case of vf-lag make sure to provide the PCI
                                                        of the first pf always for the second port
							e.g 0000:02:00.0 pf1vf[0-15].
							You can reuse this option for another devices
	--pmd-cpu-mask	<core_bitmask>			A core bitmask that sets which cores are used by
							OVS-DPDK for datapath packet processing
							e.g 0xc
	--port)		<port number>			OVS manager port default to 6000

	"
      exit 0
      ;;

   *)
      echo "No such option!!"
      echo "Exitting ...."
      exit 1
  esac
done

rm -f ${OVS_RUNDIR}/ovs-vswitchd.pid
rm -f ${OVS_RUNDIR}/ovsdb-server.pid

#Stop ovs when stop the container
function quit() {
    /usr/share/openvswitch/scripts/ovs-ctl stop
    exit 1
}
trap quit SIGTERM

# Start ovsdb.
/usr/share/openvswitch/scripts/ovs-ctl start --no-ovs-vswitchd --system-id=random

# Enable DPDK
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true

# Add dpdk-extra args.
if [[ -n "${dpdk_extra}" ]]
then
    ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-extra="--log-level=pmd,8 ${dpdk_extra}"
fi

# Add pmd-cpu-mask
if [[ -n "${pmd_cpu_mask}" ]]
then
    ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask="${pmd_cpu_mask}"
fi

# Start ovs-vswitchd
/usr/share/openvswitch/scripts/ovs-ctl start --no-ovsdb-server --system-id=random

# Set ovs manager.
ovs-vsctl set-manager ptcp:"${port}"

# Create br0-ovs bridge
ovs-vsctl --may-exist add-br br0-ovs -- set bridge br0-ovs datapath_type=netdev

# Run forever.
while true
do
  tail -f /dev/null & wait ${!}
done
