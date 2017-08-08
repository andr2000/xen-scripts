#!/bin/sh
#
# Setup XenStore entries for sound paravirtualized driver.
#
# Copyright (c) 2016 Oleksandr Andrushchenko
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

XSWRITE=`which xenstore-write`

PVDEV_NAME="vsnd"
FRONTEND_ID=$1
BACKEND_ID=0
DEV_ID=0

usage () {
        echo "Usage: `basename $0` <frontend-id>"
        echo "    <frontend-id>: the domain id of frontend"
        exit 1
}

guess_domain () {
	FRONTEND_ID=`xl list | grep -i "info" | awk '{print $2}'`
	echo "Guessing DomU to be \"$FRONTEND_ID\""
	if [ -z "$FRONTEND_ID" ]; then
		return 1
	fi
	return 0
}

# no default parameters, if not 1 then try guessing or quit
[ $# -eq 1 ] || guess_domain || usage

# Configure PV sound generic entries
./cfg-pvback.sh $PVDEV_NAME $FRONTEND_ID $BACKEND_ID $DEV_ID

# Configure playback/capture parameters for Domain $1
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/short-name "Card 0 short name"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/long-name "Card 0 long name"
#$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/sample-formats "s8;u8;s16_le;s16_be"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/buffer-size 262144

$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/name "General analog"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/0/type "p"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/0/unique-id 0
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/1/type "c"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/1/unique-id 1

$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/1/name "HDMI-0"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/1/0/type "c"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/1/0/unique-id 2

$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/2/name "SPDIF"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/2/0/type "p"
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/2/0/unique-id 3
