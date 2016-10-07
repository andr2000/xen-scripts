#!/bin/bash
echo "Configuring bridge..."
modprobe tun
ifconfig eth0:1 192.168.0.1
brctl addbr xenbr0
brctl addif xenbr0 eth0:1
ifconfig eth0:1 up
ifconfig xenbr0 up
