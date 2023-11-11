# Peek
This's a repository template for my configure and setting files backup by Git.


## Get Start
```sh
git clone git@github.com:mianjune/peek.git
cd peek

# Optional: new branch and worktree directory for a dataset
b=$(hostname 2>/dev/null||hostnamectl hostname)
git worktree -b "${b}" "backup-${b}"
cd $_

# modify or add updating scripts you need below .bin/ (`update_*.sh`, disable by rename appending `.off`)
# execute updating scripts
ls ./.bin/update_*.sh|xargs -l1 sh {}
# and track files into repository
git add -f .bin/update_*.sh ...files_for_backup

# re amend commit
./.bin/backup_schedule.sh

# update crontab, like:
# 3 10-23,0 * * * /path_to/backup/.bin/backup.sh schedule &> /tmp/cron-`whoami`-backup-schedule.log &
```

