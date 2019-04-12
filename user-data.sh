#!/bin/bash

## This script isn't meant to be run on it's own. It's read and passed into the Droplets that are created and gets run on their initial startup

## If you're using DO's firewall, you might want to disable UFW
## sudo ufw disable
## sudo service ufw stop

## Update UFW to allow for Swarm mode
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp
## By default, rate limiting is enabled on port 22
## sudo ufw allow 22/tcp
ufw reload

## Restart Docker Daemon
systemctl restart docker

## Crontab to clear bash history - runs everynight at 11pm
crontab -l -u root | echo "00 23 * * * cat /dev/null > ~/.bash_history" | crontab -u root -

## Set timezone to EST
sudo timedatectl set-timezone EST

## Update Ubuntu, bypass prompts, Remove obsolete Ubuntu packages
## This dramatically increases the amount of time it takes to create the images.
sudo apt -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade
sudo apt-get -y autoremove

## Remove environment variable
unset DEBIAN_FRONTEND