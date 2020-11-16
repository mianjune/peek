# Backup
This is a Git version for my configure and setting files.


## Get Start
```console
git clone git@github.com:mianjune/backup.git
cd backup

# new branch
git checkout -b your_name

# modify or add updater you need below bin/, script like `update_*.sh` (trun script off by rename append `.old`)

# initiate backup files and add to Git forcely
./tools/backup_schedule.sh
git add -f ...
# re amend commit
./tools/backup_schedule.sh

# update crontab, like:
# 3 10-23,0 * * * /path_to/backup/bin/schedule.sh &> /tmp/cron-`whoami`-backup-schedule.log &
```

