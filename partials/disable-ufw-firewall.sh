#!/bin/bash

## This is pulled into the user-data script. Not meant to be run on its own

## If you're using DO's firewall, this disables UFW
sudo ufw disable
sudo service ufw stop