# Backup
This is a repository template for my configure and setting files by Git.


## Get Start
```console
git clone git@github.com:mianjune/backup.git
cd backup

# Optional: new branch
# git checkout -b new_branch_for_backup_set

# modify or add updating scripts you need below bin/ (`update_*.sh`, disable by rename appending `.old`)
# execute updating scripts
ls ./bin/update_*.sh|xargs -l1 sh {}
# and track files into repository
git add -f bin/update_*.sh ...files_for_backup

# re amend commit
./bin/backup_schedule.sh

# update crontab, like:
# 3 10-23,0 * * * /path_to/backup/bin/backup.sh schedule &> /tmp/cron-`whoami`-backup-schedule.log &
```

