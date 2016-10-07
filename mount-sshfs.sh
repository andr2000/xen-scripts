#!/bin/bash
MOUNT_POINT=~/hostfs
echo "Reading config.cfg" >&2
mkdir -p ${MOUNT_POINT}
source config.cfg
echo "Mounting host folder ${user}@${host}:${path} to ${MOUNT_POINT}"
./sshfs -o allow_other ${user}@${host}:${path} ${MOUNT_POINT}
