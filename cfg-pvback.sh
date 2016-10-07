#!/bin/sh 
# 
# Setup XenStore entry for paravirtualized USB driver. 
# 
# Written by Noboru Iwamatsu <[hidden email]> 
# 

XSWRITE=/usr/bin/xenstore-write 
XSCHMOD=/usr/bin/xenstore-chmod 

DEV_NAME=vusb 
# Max 16 ports. 
NUM_PORTS=8 

usage () { 
    echo "Usage: `basename $0` <frontend-id> <device-id>" 
    echo "    <frontend-id>: the domain id of frontend" 
    echo "    <device-id>: the device id of frontend" 
    echo "" 
    echo "Example:" 
    echo "    If you use paravirtual USB driver on Domain ID 1," 
    echo "    simply do" 
    echo "    `basename $0` 1 0" 
    exit 1 
} 

[ $# -eq 2 ] || usage 

DEV_ID=$2 

# Write backend information into the location that frontend look for. 
$XSWRITE /local/domain/$1/device/$DEV_NAME/$DEV_ID/backend-id 0 
$XSWRITE /local/domain/$1/device/$DEV_NAME/$DEV_ID/backend \ 
/local/domain/0/backend/$DEV_NAME/$1/$DEV_ID 

# Write frontend information into the location that backend look for. 
$XSWRITE /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/frontend-id $1 
$XSWRITE /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/frontend \ 
/local/domain/$1/device/$DEV_NAME/$DEV_ID 

# Write virtual root hub field. 
$XSWRITE /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/num-ports $NUM_PORTS 
for i in $(seq 1 $NUM_PORTS) 
do 
        # Set all port to disconnected state 
        $XSWRITE /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/port-$i "0" 
done 

# Set permission 
$XSCHMOD /local/domain/$1/device/$DEV_NAME/$DEV_ID n$1 r0 
$XSCHMOD /local/domain/$1/device/$DEV_NAME/$DEV_ID/backend-id n$1 r0 
$XSCHMOD /local/domain/$1/device/$DEV_NAME/$DEV_ID/backend n$1 r0 
$XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID n0 r$1 
$XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/frontend-id n0 r$1 
$XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/frontend n0 r$1 
$XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/num-ports n0 r$1 
for i in $(seq 1 $NUM_PORTS) 
do 
        $XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/port-$i n0 r$1 
done 

# Set state to XenbusStateInitialising 
$XSWRITE /local/domain/$1/device/$DEV_NAME/$DEV_ID/state 1 
$XSCHMOD /local/domain/$1/device/$DEV_NAME/$DEV_ID/state n$1 r0 
$XSWRITE /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/state 1 
$XSCHMOD /local/domain/0/backend/$DEV_NAME/$1/$DEV_ID/state n0 r$1 

