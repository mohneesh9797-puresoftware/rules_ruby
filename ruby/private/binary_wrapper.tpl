#!/bin/sh

if [ -n "${RUNFILES_DIR+x}" ]; then
  PATH_PREFIX=$RUNFILES_DIR/{workspace_name}/
elif [ -s `dirname $0`/../../MANIFEST ]; then
  PATH_PREFIX=`cd $(dirname $0); pwd`/
elif [ -d $0.runfiles ]; then
  PATH_PREFIX=`cd $0.runfiles/{workspace_name}; pwd`/
else
  echo "WARNING: it does not look to be at the .runfiles directory" >&2
  exit 1
fi

$PATH_PREFIX{interpreter} --disable-gems {init_flags} {rubyopt} -I${PATH_PREFIX} ${PATH_PREFIX}{main} "$@"
