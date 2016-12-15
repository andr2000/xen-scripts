# Make sure that $DISPLAY is unset.
#https://www.collabora.com/news-and-blog/blog/2016/06/03/running-weston-on-a-raspbian/
unset DISPLAY

# And that $XDG_RUNTIME_DIR has been set and created.
if test -z "${XDG_RUNTIME_DIR}"; then
  export XDG_RUNTIME_DIR=/tmp/${UID}-runtime-dir
  rm -rf "${XDG_RUNTIME_DIR}"
  mkdir "${XDG_RUNTIME_DIR}"
  chmod 0700 "${XDG_RUNTIME_DIR}"1
fi

# Run weston:
weston --tty=`tty`
