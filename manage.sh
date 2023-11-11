#!/bin/sh

base_dir=$(cd $(dirname $(readlink -f "$0"))/..; pwd -P)
bin_dir=$base_dir/peek.d

cd $base_dir


_log() { printf "\e[1;33m[`date '+%F %T'`] \e[37m$*\e[0m\n"; }
_logerr() { _log "\e[31m$*"; }
_exec() { _log "> \e[32m$*\e[0m\n"; "$@"; }
export -f _log # sub process

_usage() { printf %b "\e[1;32m$0\e[0m version: v1.0 by Mianjune
A backup manager script

Usage: \e[1;32m$0 SUB_COMMAND\e[0m

Commands:
	\e[1;32mnew      TASK\e[0m	new task
	\e[1;32mlist         \e[0m	list all tasks
	\e[1;32medit     TASK\e[0m	edit the task script with save to repository
	\e[1;32mexec|run [TASK]\e[0m	refresh data and save to repository by task
	\e[1;32menable   TASK\e[0m	enable the task
	\e[1;32mdisable  TASK\e[0m	disable the task

"; }

_edit_file() {
	_last=$(stat -c%Y "$1")
	"${EDITOR:-vim}" "$1"
	[ $_last -lt $(stat -c%Y "$f") ] || { _log no changes effected; return 1; }
}

_get_script() { # get script full path by task name
	: "$(basename $1)"
	f=$bin_dir/${_%%.*}.sh
	[ -f "$f" ] || {
		f=$f.off
		[ -f "$f" ] || unset f
	}
	printf "$f"
}


######## Commands ########
_new() {
	_log "create \e[4;32m$*"
	f=$1
	[ -n "$f" ] || { _logerr "a task name required!!"; return 1; }
	f=$(_get_script "$f")
	[ -z "$f" ] || {
		_logerr "task existed: \e[4;34m$f"
		printf "\e[1;33medit \e[4;34m${f##*/}\e[0;1m? y/N "; read c
		[[ "$c" == [yY] ]] && _edit "$f"
		return
	}
	f="$bin_dir/${1##*/}.sh"
	cp -in "$bin_dir/template.sh.off" "$f" || return 1

	if _edit_file "$f"; then
		_enable "${f%.sh}"
		printf "\e[1mfor execute it by: \e[32mrun \e[33m$(basename "$_")\n"
	else
		rm "$f"
	fi
}

_edit() {
	f=$1
	[ -n "$f" ] || { _logerr "a task name required!!"; return 1; }
	f=$(_get_script "$f")
	[ -n "$f" ] || {
		_logerr "task[${1##*/}] not found!!"
		printf "\e[1;33mcreate \e[4;34m${1##*/}\e[0;1m? y/N "; read c
		[[ "$c" == [yY] ]] && _new "${1##*/}"
		return
	}
	_log "edit \e[4;32m$f"

	_edit_file "$f" && _exec git commit -m "[manage] modify '$(basename "${f%.*}")'" -- "$f"
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

_updates() { # args: [name]
	_log schedule updating
	if [ $# -gt 0 ]; then
		for f in "$@"; do
			f=$(_get_script "$f")
			[ -z "$f" ] && { _logerr "script not found!!"; return 1; }

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
	[ $# -gt 0 ] || { _logerr "a script required!!"; return 1; }
	while [ $# -gt 0 ]; do
		local f=$(_get_script "$1")
		[ -z "$f" ] && { _logerr "script[$1] not found!!"; return 1; }

		_exec chmod +x "$f"
		_exec git add -f "$f"
		f_new="$f"
		if [[ "$f" != *.sh ]]; then
			f_new="${f%.*}"
			[[ "$f_new" != *.sh ]] && { _logerr "wrong script name!!"; return 1; }

			_exec git mv "$f" "$f_new"
		fi

		_exec git commit -m "[manage] enable '$(basename "${f_new%.*}")' schedule"
		shift; unset f_new
	done
}

_disable() { # arg1: script_path
	_log "disable \e[4;32m$*\e[0m"
	[ $# -gt 0 ] || { _logerr "a script required!!"; return 1; }
	while [ $# -gt 0 ]; do
		local f=$(_get_script $1); shift
		[[ "$f" == *.sh ]] && {
			_exec git add -f "$f"
			_exec git mv "$_" "$f.off"
			_exec git commit -m "[manage] disable '$(basename "${f%.*}")' schedule"
		}
	done
}


case $1 in
	ls|list)	_list;;
	add|new)	_new "${@:2}";;
	exec|run)	_updates "${@:2}";;
	edit)		_edit "${@:2}";;
	enable)		_enable "${@:2}";;
	disable)	_disable "${@:2}";;
	*)			_usage; exit 1;
esac
