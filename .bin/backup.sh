#!/bin/sh

bin_dir=$(cd $(dirname "$0"); pwd -P)
base_dir=$bin_dir/..

cd $base_dir


_exec() { echo -e "> \e[1;32m$*\e[0m"; "$@"; }

_usage() { echo -e "\e[32m$0\e[0m version: v1.0 by Mianjune
A backup manager

Usage: \e[32m$0 SUB_COMMAND\e[0m

Commands:
    \e[32mschedule\e[0m          update backup data and commit to repository
    \e[32menable  SCRIPT\e[0m    enable the udpating script
    \e[32mdisable SCRIPT\e[0m    disable the udpating script
"; }


_schedule() {
    echo -e "\e[33m[`date '+%F %T'`] \e[32mschedule\e[0m"
    # refresh backup data
    for f in $bin_dir/update_*.sh; do
        echo -e "\e[33m[`date '+%F %T'`] \e[0mexecute \e[32m$f ...\e[0m"
        $f
    done


    # commit updates
    [ -n "$(git status -uno -s)" ] && {
        # keep commits group by one day
        today=$(date +%Y%m%d)
        
        [[ $(git show -s --pretty=format:%as|tr -d -- -) == $today && $(git show -s --pretty=%s) == "[schedule]"* ]] && \
            commit_options='--amend'


        msg="[schedule] ${today}: backup ${USER}@$(hostname 2>/dev/null||hostnamectl hostname)"

        echo -e "\e[33m[`date '+%F %T'`] \e[32mcommit \e[1m$msg\e[0m"
        git commit ${commit_options} -am "$msg"
    }
} 


_enable() { # arg1: script_path
    echo -e "\e[33m[`date '+%F %T'`] \e[32menable \e[1m$*\e[0m"
    [ $# -gt 0 ] || { echo -e "\e[31ma script required!!\e[0m"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(basename $1)

        _exec chmod +x "$bin_dir/$f"
        _exec git add -f "$bin_dir/$f"
        if [[ "$f" != *.sh ]]; then
            f2="${f%.*}"
            [[ "$f2" != *.sh ]] && { echo -e "\e[31mwrong script name!!\e[0m"; return 1; }

            _exec git mv "$bin_dir/$f" "$bin_dir/$f2"
        fi

        _exec git commit -m "[enable] ${f2:-$f}"
        shift; unset f2
    done
} 

_disable() { # arg1: script_path
    echo -e "\e[33m[`date '+%F %T'`] \e[32mdisable \e[1m$*\e[0m"
    [ $# -gt 0 ] || { echo -e "\e[31ma script required!!\e[0m"; return 1; }
    while [ $# -gt 0 ]; do
        local f=$(basename $1)
        [[ "$f" == *.sh ]] && {
            _exec git add -f "$bin_dir/$f"
            _exec git mv "$_" "$bin_dir/$f.off"
            _exec git commit -m "[disable] $f"
        }
        shift
    done
} 


case $1 in
    schedule) _schedule;;
    enable)   _enable "${@:2}";;
    disable)  _disable "${@:2}";;
    *)        _usage; exit 1;
esac
