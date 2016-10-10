#!/bin/sh
#
# Setup XenStore entries for audio paravirtualized driver.
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

PVDEV_NAME="vaudio"
FRONTEND_ID=1
BACKEND_ID=0
DEV_ID=0


# Configure PV audio generic entries
./cfg-pvback.sh $PVDEV_NAME $FRONTEND_ID $BACKEND_ID $DEV_ID

# Configure playback/capture parameters for Domain 1
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/0/type playback
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/1/type playback
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/2/type playback

$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/3/type capture
$XSWRITE /local/domain/$FRONTEND_ID/device/$PVDEV_NAME/$DEV_ID/4/type capture
