#!/bin/sh

base_dir=$(cd $(dirname $(readlink "$0"))/..; pwd -P)
bin_dir=$base_dir/.bin/update.d

cd $base_dir


_log() { printf "\e[1;33m[`date '+%F %T'`] \e[37m$*\e[0m\n"; }
_exec() { _log "> \e[32m$*\e[0m\n"; "$@"; }
export -f _log # sub process

_usage() { printf %b "\e[1;32m$0\e[0m version: v1.0 by Mianjune
A backup manager

Usage: \e[1;32m$0 SUB_COMMAND\e[0m

Commands:
    \e[1;32mnew		TASK\e[0m	new task
    \e[1;32mlist	\e[0m	list all tasks
    \e[1;32mexec|run	[TASK]\e[0m	refresh data and commit to repository by task
    \e[1;32menable	TASK\e[0m	enable the task
    \e[1;32mdisable	TASK\e[0m	disable the task

"; }


_new() {
  _log "create \e[4;32m$*\e[0m"
  f=$1
  [ -n "$f" ] || { _log "\e[31ma task name required!!"; return 1; }
  f=$(_get_script "$f")
  [ -z "$f" ] || { _log "\e[31mtask existed: \e[4;32m$f"; return 1; }
  f="$bin_dir/$f.sh"
  cp -in "$bin_dir/template.sh.off" "$f" && "${EDITOR:-vim}" "$f"
  _enable "${f%.sh}"
  printf "\e[1mfor execute it by: \e[32m./backup.sh update $(basename "$_")\n"
}

_list() {
  _l=$(ls "$bin_dir")
  _lm=$(($(<<<"$_l" sed 's .off$  '|wc -L)+3))
  while read f; do
    printf "\e[1;$(
      printf "%-${_lm}s" "$(<<<"$f" sed -r "s/^(.+)\.sh\.off/36m# \1/;t;s/^/32m  /;s \.sh  ")"
      desc=$(sed -r '/^#!/D;/^#/{:f;n;/^#/!Q;bf};d' "$bin_dir/$f"|sed -r 's ^#\s*  '|tr '\n' \ )
      [ -n "$desc" ] && printf "\e[37m- $desc"
    )\n"
  done <<<"$_l"
}

_get_script() {
  f="$(basename $1)"
  f=$bin_dir/${f%%.*}.sh
  [ -f "$f" ] || {
    f=$f.off
    [ -f "$f" ] || unset f
  }
  printf "$f"
}

_updates() { # args: [name]
  _log schedule updating
  if [ $# -gt 0 ]; then
    for f in "$@"; do
      f=$(_get_script "$f")
      [ -z "$f" ] && { _log "\e[31mscript not found!!"; return 1; }

      _update "$f"
    done
  else
    for f in $bin_dir/*.sh; do
      _update "$f"
    done
  fi
} 

_update() {
  f="$1"
  _log "execute \e[32m$f \e[37m..."
  # refresh backup data
  "$f"

  # commit updates
  [ -n "$(git status -uno -s)" ] && {
    : "${f%.off}"
    msg="[schedule.$(date '+%Y%m%d')] $(basename "${_%.sh}"): by ${USER}@$(cat /etc/hostname)"

    _log "commit \e[32m$msg"
    git commit -am "$msg"
  }
}

_enable() { # arg1: script_path
    _log "enable \e[4;32m$*\e[0m"
    [ $# -gt 0 ] || { _log "\e[31ma script required!!"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(_get_script "$1")
        [ -z "$f" ] && { _log "\e[31mscript not found!!"; return 1; }

        _exec chmod +x "$f"
        _exec git add -f "$f"
        f_new="$f"
        if [[ "$f" != *.sh ]]; then
            f_new="${f%.*}"
            [[ "$f_new" != *.sh ]] && { _log "\e[31mwrong script name!!"; return 1; }

            _exec git mv "$f" "$f_new"
        fi

        _exec git commit -m "[manage] enable '$(basename "${f_new%.*}")' schedule"
        shift; unset f_new
    done
} 

_disable() { # arg1: script_path
    _log "disable \e[4;32m$*\e[0m"
    [ $# -gt 0 ] || { _log "\e[31ma script required!!"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(_get_script $1)
        [[ "$f" == *.sh ]] && {
            _exec git add -f "$f"
            _exec git mv "$_" "$f.off"
            _exec git commit -m "[manage] disable '$(basename "${f%.*}")' schedule"
        }
        shift
    done
} 


case $1 in
  ls|list)	_list;;
  add|new)	_new "${@:2}";;
  exec|run)	_updates "${@:2}";;
  enable)	_enable "${@:2}";;
  disable)	_disable "${@:2}";;
  *)		_usage; exit 1;
esac
