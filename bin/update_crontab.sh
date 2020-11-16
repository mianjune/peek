#!/bin/sh

mkdir -p crontab &&\
crontab -l >| crontab/${USER}.crontab

