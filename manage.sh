#!/bin/bash

base_dir=$(cd "$(dirname "$0")"; pwd)
peek_dir=.peek
conf_dir=peek.d


_log()	{ printf "\e[0m`date +%T`\e[34m \e[1m$*\e[0m\n" >&2; }
_exec()	{ _log "> \e[32m$*\e[0m\n"; "$@"; }
_err()	{ _log "\e[31m${*//\e[39m/\e[31m}"; }
_is()	{ printf "\e[1m# \e[33m$*\e[0;1m? (Y/n)\e[0m "; local c; read -r c; ! [[ "$c" =~ [nN] ]]; }
_isn()	{ printf "\e[1m# \e[33m$*\e[0;1m? (y/N)\e[0m "; local c; read -r c; [[ "$c" =~ [yY] ]]; }
_ask()	{ printf "\e[1mDo> \e[32m$*\e[0;1m? (Y/n)\e[0m "; local c; read -r c; case "$c" in [nN]) return;; esac; _exec "$@"; }
export -f _log _err _exec # sub process

_usage() { printf %b "\e[1;32m$0\e[0m version: v1.0 by Mianjune
A backup manager script

Usage: \e[1;32m$0 SUB_COMMAND\e[0m

Commands:
	\e[1;32madd|new TASK\e[0m		new task
	\e[1;32mls|list\e[0m			list all tasks
	\e[1;32medit TASK\e[0m		edit the task by name
	\e[1;32mexec|run TASK\e[0m		execute task and save changes
	\e[1;32mschedule -e|-l|NAME\e[0m	list schedule(-l); edit schedule(-e); run schedule by name

	\e[1;32minit [PROJECT_DIR [PEEK_GIT_URL]]\e[0m	init project Peek
	\e[1;32mupgrade\e[0m					upgrade Peek

"; }

# Edit file and check is modified
_edit_file() { # args: FILE_PATH
	local _last=$(stat -c%Y "$1")
	_log "edit: \e[4;32m$1"
	"${EDITOR:-vim}" "$1"
	[ "${_last:-0}" -lt "$(stat -c%Y "$1")" ] || { _log no changes effected; return 1; }
}

_get_task_script_by_name() { # get script full path by task name
	: "$(basename "$1")"
	printf "${_%.sh}"
}


######## Commands ########
_new() { # args: NAME
	_log "create task: \e[4;32m$*"
	[ -n "$1" ] || { _err "a task name required!!"; return 1; }
	local n=$(_get_task_script_by_name "$1")
	local i f="$conf_dir/$n.sh"
	cd "$base_dir"
	if [ -f "$f" ]; then
		_is "task[\e[32m$n\e[33m] existed, do edit it" && _edit "$n"
	else
		local t
		_log "choose a template"
		select i in $(find "$conf_dir" "$peek_dir"/peek.d -type f -name '*.sh'|sort); do
			cp -in "$i" "$f" || return 1
			break
		done
		
		if _edit_file "$f"; then
			git add -- "$f"
			git status -suno; _exec git commit -m "manage(task): new [$n]" -- "$f"
			_is "Do> ./manage.sh run \e[32m$n" && _run "$n"
		else
			rm "$f"
		fi
	fi
}

_edit() { # args: NAME
	[ -n "$1" ] || { _err "a task name required!!"; return 1; }
	local n=$(_get_task_script_by_name "$1")
	local f="$conf_dir/$n.sh"
	cd "$base_dir"
	if [ -f "$f" ]; then
		if _edit_file "$f"; then
			git add -- "$f"
			git status -suno; _exec git commit -m "manage(task): modify [$n]" -- "$f"
		fi
	else
		_is "task[\e[32m$n\e[33m] not found, do create it" && _new "$n"
	fi
}

# List all tasks
_list() {
	cd "$base_dir"
	local l=$(ls "$conf_dir"|grep '.sh$'|sort)
	local f lm=$(wc -L <<<"$l")
	while read f; do
		printf " \e[1;32m%-${lm}s\e[39m%s\e[0m\n" "${f%.sh}" "$(sed -r '/^#!/D;/^#/{:f;n;/^#/!Q;bf};d' "$conf_dir/$f" 2>/dev/null|sed -r 's/^#\s*//;1s/^/- /'|tr '\n' \ )"
	done <<<"$l"
}

_schedule() { # args: [name]
	cd "$base_dir"
	# Reformat variable name
	local f="$conf_dir/schedule.conf"
	case "$1" in
		'') _usage; exit 1;;
		-e) # Edit schedule config
			[ -f "$f" ] || _exec cp -i "$peek_dir"/peek.d/schedule.conf "$f"
			if _edit_file "$f"; then
				git add -- "$f"
				git status -suno; _exec git commit -m "manage(schedule): modify" -- "$f"
			fi ;;
		*) # Load schedule.conf
			source <(sed -r 's/^\w+=/peek_schedule_&/' "$f") ;;&
		-l) # Show schedules
			compgen -A variable | grep '^peek_schedule_'| while read f; do
				printf '\e[1;33m# %s' "${f#peek_schedule_}"
				: "${f}[*]"
				if [ -n "${!_}" ]; then
					: "${f}[@]"
					printf '\n  \e[1;32m- %s' "${!_}"
				fi
				printf '\e[0m\n'

			done ;;
		*) # Execute schedule by name
			local s="peek_schedule_$1[@]"
			for f in "${!s}"; do
				local _task_existed=1
				SCHEDULE_NAME="$1" _run "$f"
			done
			[ -v _task_existed ] || { _err "There are not tasks in schedule[$1]!!"; return 1; }
	esac
}

# Run a task
_run() {
	[ -n "$1" ] || { _err "a task name required!!"; return 1; }
	local n=$(_get_task_script_by_name "$1")
	local f="$conf_dir/$n.sh"
	cd "$base_dir"
	if [ -f "$f" ]; then
		_log "execute > \e[32m$n"
		# Refresh backup data
		cd "$base_dir"
		"$f" || { _err "Fail to exec: \e[37m$f\e[37m!!"; return 1; }

		# Check if changes
		git diff-index --quiet HEAD && { _err "nothing changed by \e[32m$n\e[39m!!"; return 1; }

		# Commit updates
		git status -suno; _exec git commit -m "task($n): update by${SCHEDULE_NAME:+ schedule[${SCHEDULE_NAME}]} ${USER:-$(whoami)}@$(cat /etc/hostname)"
	else
		_isn "task[\e[32m$n\e[33m] not found, do create it" && _new "$n"
	fi

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

	_exec ln -s .peek/manage.sh || return 1

	# Commit
	git add -- .peek/ manage.sh .gitmodules
	git status -suno
	_ask git commit -m "feat: setup Peek($(git config submodule.peek.url))" -- .peek/ manage.sh .gitmodules

	_exec ./manage.sh --help
	printf 'Has installed \e[33mPeek\e[0m in \e[34m.peek/\e[0m by git-submodule\ntry it and create a task by 👉 \e[1;32m./manage.sh new\e[0m ...\n'
}

_upgrade() {
	cd "$base_dir"
	_exec git submodule update --remote --checkout -- .peek || return 1
	git diff-index --quiet HEAD .peek && { _err "nothing upgraded!!"; return 1; }
	_ask git commit -m "manage(upgrade): Peek | $(git --git-dir=.peek/.git log -n1 --format=format:'%h %as %s')" -- .peek
}


case "$1" in
	# Task
	ls|list)	_list;;
	schedule)	_schedule "${@:2}";;
	exec|run)	_run "${@:2}";;
	edit)		_edit "${@:2}";;
	add|new)	_new "${@:2}";;

	# Manager
	upgrade)	_upgrade "${@:2}";;
	init)		_init "${@:2}";;

	# Help
	*)			_usage; exit 1
esac
