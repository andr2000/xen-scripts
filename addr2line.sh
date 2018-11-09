#/bin/bash -x -e

usage()
{
    me=`basename "$0"`

    echo "${me} <obj_file> <func_name>+[offset]"
    echo "	obj_files	object file name"
    echo "	func_name	function name"
    echo "	func_offset	offset within the function, 0 by default"

    if [ -n "$1" ]; then
        echo "$1"
    fi

    exit 1
}

if [ "$#" != "2" ]
then
    usage "Not enough parameters"
fi

obj_file=$1
target=$2

IFS='+' read -r -a array <<< "$target"

func_name=${array[0]}
offset=${array[1]}
: ${offset:=0}

ADDR2LINE="${CROSS_COMPILE}addr2line"

base_addr=` ${OBJDUMP} -D -S ${obj_file} | grep "<${func_name}>:" | cut -f 1 -d " "`
addr=`printf "%X\n" $(( 0x$base_addr + $offset ))`
${ADDR2LINE} -e ${obj_file} $addr
