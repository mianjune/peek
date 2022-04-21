#!/bin/sh

base_dir=$(cd $(dirname $(readlink "$0"))/..; pwd -P)
bin_dir=$base_dir/.bin/update.d

cd $base_dir


_exec() { printf "> \e[1;37m$*\e[0m\n"; "$@"; }
_log() { printf "\e[1;33m[`date '+%F %T'`] \e[32m$*\e[0m\n"; }

_usage() { printf %b "\e[1;32m$0\e[0m version: v1.0 by Mianjune
A backup manager

Usage: \e[1;32m$0 SUB_COMMAND\e[0m

Commands:
    \e[1;32mlist\e[0m		list all updating scripts
    \e[1;32mschedule\e[0m		update backup data and commit to repository
    \e[1;32menable  SCRIPT\e[0m	enable the updating script
    \e[1;32mdisable SCRIPT\e[0m	the updating script

"; }


_list() {
  _e=$'\e['
  ls $bin_dir|grep .sh|sed -r "s/^(.+)\.off/${_e}1;36m# \1/;tr;s/^/${_e}1;32m  /;:r;s \.sh  ;s \$ ${_e}0m "
}


_schedule() { # args: name
  _log schedule
  # refresh backup data
  for f in $bin_dir/*.sh; do
    _log "execute \e[32m$f \e[37m..."
    $f


    # commit updates
    [ -n "$(git status -uno -s)" ] && {
      msg="[schedule] $(basename "${f%.sh}"): by ${USER}@$(cat /etc/hostname)"

      _log "commit \e[32m$msg"
      git commit -am "$msg"
    }
  done
} 


_enable() { # arg1: script_path
    _log "enable \e[4;32m$*\e[0m"
    [ $# -gt 0 ] || { _log "\e[31ma script required!!"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(basename $1)

        _exec chmod +x "$bin_dir/$f"
        _exec git add -f "$bin_dir/$f"
        if [[ "$f" != *.sh ]]; then
            f2="${f%.*}"
            [[ "$f2" != *.sh ]] && { _log "\e[31mwrong script name!!"; return 1; }

            _exec git mv "$bin_dir/$f" "$bin_dir/$f2"
        fi

        _exec git commit -m "[manage] enable ${f2:-$f}"
        shift; unset f2
    done
} 

_disable() { # arg1: script_path
    _log "disable \e[4;32m$*\e[0m"
    [ $# -gt 0 ] || { _log "\e[31ma script required!!"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(basename $1)
        [[ "$f" == *.sh ]] && {
            _exec git add -f "$bin_dir/$f"
            _exec git mv "$_" "$bin_dir/$f.off"
            _exec git commit -m "[manage] enable $f"
        }
        shift
    done
} 


case $1 in
  ls|list)	_list;;
  schedule)	_schedule;;
  enable)	_enable "${@:2}";;
  disable)	_disable "${@:2}";;
  *)		_usage; exit 1;
esac
