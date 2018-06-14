#!/bin/bash

# First argument is base branch version, e.g. xen_tip_xxx_v
base_branch=$1
# Second and third args are the suffixes to be applied to the base branch
branch_left="${base_branch}$2"
branch_right="${base_branch}$3"
# Fourth and fifth args are suffixes for HEAD~
left_commit_num=$4
right_commit_num=$5

left_sha1=`git log --format=format:%h ${branch_left} | sed "${left_commit_num}q;d"`
right_sha1=`git log --format=format:%h ${branch_right} | sed "${right_commit_num}q;d"`

echo
echo =========================== LEFT: ${branch_left}:HEAD~${left_commit_num}
git log -n 1 ${left_sha1}

echo
echo =========================== RIGHT: ${branch_right}:HEAD~${right_commit_num}
git log -n 1 ${right_sha1}

echo
echo =========================== THE DIFF ======================================
meld --diff <(git show ${left_sha1}) <(git show ${right_sha1})
