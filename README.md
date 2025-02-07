# Peek
A manage.sh to backup data by Git, for my dotfiles, package versions, setting files, etc.


## Get Start
```sh
# create a new directory, open your existed backup repository
mkdir YOUR_DIR_FOR_SAVE_BACKUP_DATA/
cd "$_"

# init Peek
bash <(curl -sL https://raw.githubusercontent.com/mianjune/peek/main/manage.sh) init
# or wget
bash <(wget -O- https://raw.githubusercontent.com/mianjune/peek/main/manage.sh) init

# Add your scripts in peek.d/*.sh (disable by renamed appending `.off`)
./manage.sh new TASK_NAME

# Add crontab schedule like:
# 3 10-23,0 * * * /path/to/peek/backup/dir/manage.sh run &>> /tmp/cron-`whoami`-backup-schedule.log &
```


## Troubleshooting
```sh
# reset submodule module
git submodule update --init -f .peek
```
