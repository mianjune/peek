#!/bin/sh

base_dir=$(dirname "$0")/..

cd $base_dir

for s in $(ls ./bin/update_*.sh); do
    echo execute $s ...
    $s
done


[ -n "`git status -uno -s`" ] && {
    # keep commit by a day
    today=`date +%Y%m%d`
    if [ `git show -s --pretty=format:%as |tr -d -- -` == $today ]; then
        git commit -a --amend  --no-edit
    else
        git commit -am "[schedule] ${today}: backup '${USER}'"
    fi
}

