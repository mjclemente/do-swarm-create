#!/bin/bash

## This script isn't meant to be run on it's own. It's read and passed into the Droplets that are created and gets run on their initial startup

## Here's a bit more on what/how this data is used:
## - https://www.digitalocean.com/docs/droplets/resources/metadata/
## - https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting


## Important. The option selected for the UFW firewall (enabled/disabled) will be prepended to this script automatically before it is passed to the Droplets


## Restart Docker Daemon
systemctl restart docker

## Crontab to clear bash history - runs everynight at 11pm
crontab -l -u root | echo "00 23 * * * cat /dev/null > ~/.bash_history" | crontab -u root -

## Set timezone to EST
sudo timedatectl set-timezone EST

## Update Ubuntu, bypass prompts, Remove obsolete Ubuntu packages
## This dramatically increases the amount of time it takes to create the droplets.
sudo apt -y update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade
sudo apt-get -y autoremove

## Set back to default (https://www.debian.org/releases/sarge/alpha/ch05s02.html.en)
DEBIAN_FRONTEND=newt