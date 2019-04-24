#!/bin/bash

## This is pulled into the user-data script. Not meant to be run on its own

## Update UFW to allow for Swarm mode
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp
## By default, rate limiting is enabled on port 22
## sudo ufw allow 22/tcp
ufw reload