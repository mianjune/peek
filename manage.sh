#!/bin/bash

base_dir="$(cd "$(dirname "$0")"; pwd)"
task_dir="$base_dir"/peek.d


_log()	{ printf "\e[1;33m[`date '+%F %T'`] \e[37m$*\e[0m\n"; }
_err()	{ _log "\e[31m$*"; }
_exec()	{ _log "> \e[32m$*\e[0m\n"; "$@"; }
_is()	{ printf "\e[1m# \e[33m$*\e[0;1m? (Y/n)\e[0m "; local c; read -r c; ! [[ "$c" =~ [nN] ]]; }
_ask()	{ printf "\e[1mDo: \e[32m$*\e[0;1m? (Y/n)\e[0m "; local c; read -r c; case "$c" in [nN]) return;; esac; _exec "$@"; }
export -f _log _err _exec # sub process

_usage() { printf %b "\e[1;32m$0\e[0m version: v1.0 by Mianjune
A backup manager script

Usage: \e[1;32m$0 SUB_COMMAND\e[0m

Commands:
	\e[1;32mnew      TASK\e[0m	new task
	\e[1;32mls|list\e[0m		list all tasks
	\e[1;32medit     TASK\e[0m	edit the task script with save to repository
	\e[1;32mexec|run [TASK]\e[0m	refresh data and save to repository by task
	\e[1;32menable   TASK\e[0m	enable the task
	\e[1;32mdisable  TASK\e[0m	disable the task
	\e[1;32minit     [PROJECT_DIR [PEEK_GIT_URL]]\e[0m	init project Peek

"; }

_edit_file() { # edit file and check is modified
	local _last=$(stat -c%Y "$1")
	"${EDITOR:-vim}" "$1"
	[ $_last -lt $(stat -c%Y "$1") ] || { _log no changes effected; return 1; }
}

_get_script() { # get script full path by task name
	: "$(basename "$1")"
	local f="$task_dir/${_%%.*}.sh"
	[ -f "$f" ] || {
		f="$f".off
		[ -f "$f" ] || return 1
	}
	printf "$f"
}


######## Commands ########
_new() { # args: NAME
	_log "create task: \e[4;32m$*"
	[ -n "$1" ] || { _err "a task name required!!"; return 1; }
	local f="$(_get_script "$1")"
	[ -z "$f" ] || {
		_err "task existed: \e[4;34m$f"
		printf "\e[1;33medit \e[4;34m${f##*/}\e[0;1m? y/N "; read c
		[[ "$c" == [yY] ]] && _edit "$f"
		return
	}
	f="$task_dir/${1##*/}.sh"
	cp -in "$task_dir/template.sh.off" "$f" || return 1

	if _edit_file "$f"; then
		_enable "${f%.sh}"
		printf "\e[1mfor execute it by: \e[32mrun \e[33m$(basename "$_")\n"
	else
		rm "$f"
	fi
}

_edit() { # args: NAME
	[ -n "$1" ] || { _err "a task name required!!"; return 1; }
	local f="$(_get_script "$1")"
	if [ -z "$f" ]; then
		_err "task[${1##*/}] not found!!"
		printf "\e[1;33mcreate \e[4;34m${1##*/}\e[0;1m? y/N "; read c
		[[ "$c" == [yY] ]] && _new "${1##*/}"
	else
		_log "edit \e[4;32m$f"
		_edit_file "$f" && _exec git commit -m "manage(task): modify '$(basename "${f%.*}")'" -- "$f"
	fi
}

_list() {
	local _l=$(ls "$task_dir")
	local f _lm=$(($(<<<"$_l" sed 's .off$  '|wc -L)+3))
	while read f; do
		printf "\e[1;$(
			printf "%-${_lm}s" "$(<<<"$f" sed -r "s/^(.+)\.sh\.off/31m# \1/;t;s/^/32m  /;s \.sh  ")"
			desc=$(sed -r '/^#!/D;/^#/{:f;n;/^#/!Q;bf};d' "$task_dir/$f"|sed -r 's ^#\s*  '|tr '\n' \ )
			[ -n "$desc" ] && printf "\e[37m- $desc"
		)\n"
	done <<<"$_l"
}

_updates() { # args: [name]
	_log schedule updating
	local f
	if [ $# -gt 0 ]; then
		for f in "$@"; do
			f="$(_get_script "$f")"
			[ -z "$f" ] && { _err "script not found!!"; return 1; }
			_update "$f"
		done
	else
		for f in "$task_dir"/*.sh; do
			_update "$f"
		done
	fi
}

_update() {
	local f="$1"
	_log "execute \e[32m$f \e[37m..."
	# refresh backup data
	"$f" || { _err "Fail to exec: \e[37m$f\e[37m!!"; return 1; }

	git diff-index --quiet HEAD && { _err "nothing changed by \e[37m$f\e[37m!!"; return 1; }

	# commit updates
	: "${f%.off}"
	local msg="schedule($(basename "${_%.sh}")): update by ${USER:-$(whoami)}@$(cat /etc/hostname)"
	_log "commit: \e[32m$msg"
	git commit -am "$msg"
}

_enable() { # arg1: script_path
	_log "enable \e[4;32m$*\e[0m"
	[ $# -gt 0 ] || { _err "a script required!!"; return 1; }
	while [ $# -gt 0 ]; do
		local f=$(_get_script "$1")
		[ -z "$f" ] && { _err "script[$1] not found!!"; return 1; }

		chmod +x "$f"
		git add -f "$f"
		local f_new="$f"
		if [[ "$f" != *.sh ]]; then
			f_new="${f%.*}"
			[[ "$f_new" != *.sh ]] && { _err "wrong script name: $f!!"; return 1; }

			_exec git mv "$f" "$f_new"
		fi

		_exec git commit -m "manage(task): enable '$(basename "${f_new%.*}")' schedule"
		shift
	done
}

_disable() { # args: SCRIPT_PATH...
	_log "disable \e[4;32m$*\e[0m"
	[ $# -gt 0 ] || { _err "a script required!!"; return 1; }
	while [ $# -gt 0 ]; do
		local f="$(_get_script "$1")"; shift
		[[ "$f" == *.sh ]] && {
			git add -f "$f"
			_exec git mv "$_" "$f.off"
			_exec git commit -m "manage(task): disable '$(basename "${f%.*}")' schedule"
		}
	done
}

_init() { # [PROJECT_DIR [PEEK_GIT_URL]]
	# Git repository
	local project_dir="$1"
	if [ -z "$project_dir" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		_is "init Peek project with existed Git: \e[34m${project_dir:=$(cd "$(git rev-parse --git-dir)"/..; pwd)}" || return
		cd "$project_dir"
	else
		_is "init Peek project with current dir: \e[34m${project_dir:=$(pwd)}" && _exec git init
	fi

	# add Peek submodule
	git submodule status .peek 2>/dev/null || _exec git submodule add --name peek --depth 1 -- "${2:-https://github.com/mianjune/peek.git}" .peek

	_log generate peek.d/
	mkdir -p peek.d
	cp -p .peek/update.d/template.sh.off peek.d

	_exec ln -s .peek/manage.sh || return 1

	_exec git add peek.d/ manage.sh
	_exec git diff --name-status --cached
	_ask git commit -m "feat: setup Peek($(git config submodule.peek.url))"

	_exec ./manage.sh --help
	printf 'Has installed \e[33mPeek\e[0m in \e[34m.peek/\e[0m by git-submodule\ntry it and create a task by 👉 \e[1;32m./manage.sh new\e[0m ...\n'
}


case $1 in
	ls|list)	_list;;
	add|new)	_new "${@:2}";;
	exec|run)	_updates "${@:2}";;
	edit)		_edit "${@:2}";;
	enable)		_enable "${@:2}";;
	disable)	_disable "${@:2}";;
	init)		_init "${@:2}";;
	*)			_usage; exit 1;
esac
