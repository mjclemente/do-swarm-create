#!/bin/bash

: "${DO_DROPLET_NAME:=swarm-node}"
: "${DO_SIZE:=s-1vcpu-1gb}"
: "${DO_ENABLE_BACKUPS:=true}"
: "${DO_ENABLE_UFW:=true}"
: "${DO_REGION:=nyc1}"
: "${DO_TAGS:=$DO_DROPLET_NAME}"
: "${DO_MANAGER_COUNT:=3}"
: "${DO_WORKER_COUNT:=0}"
## Image name set for convenience (https://marketplace.digitalocean.com/apps/docker)
DO_IMAGE_NAME=docker-18-04

## Determine if backups should be enabled
if [ "$DO_ENABLE_BACKUPS" = true ]; then
  DO_ENABLE_BACKUPS="True"
  DO_BACKUP_OPTION="--enable-backups"
else
  DO_ENABLE_BACKUPS="False"
  DO_BACKUP_OPTION=""
fi

## Determine if firewall should be enabled
if [ "$DO_ENABLE_UFW" = true ]; then
  DO_ENABLE_UFW="True"
  DO_UFW_OPTION=$(cat ./partials/configure-ufw-firewall.sh)
else
  DO_ENABLE_UFW="False"
  DO_UFW_OPTION=$(cat ./partials/disable-ufw-firewall.sh)
fi

## The default is to add all the the SSH Ids in your DO account
: ${DO_SSH_IDS:=$(doctl compute ssh-key list --no-header --format ID)}

: "${DO_SSH_IDS:?Please set your DO_SSH_IDS}"
## formatting needs to be adjusted if there are multiple SSH Ids returned by doctl
DO_SSH_IDS=${DO_SSH_IDS//[[:space:]]/,}

## Provide prompt to make sure that user knows what they're doing
while true; do
    read -p "You are about to create a Swarm with the following options:

Name: $DO_DROPLET_NAME
Size: $DO_SIZE
Region: $DO_REGION
Enable Backups: $DO_ENABLE_BACKUPS
Enable UFW Firewall: $DO_ENABLE_UFW
Tags: $DO_TAGS
Managers: $DO_MANAGER_COUNT
Workers: $DO_WORKER_COUNT
SSH IDs: $DO_SSH_IDS

Do you wish to continue? " yn
    case $yn in
        [Yy]* ) echo "Proceeding with Swarm creation."; break;;
        [Nn]* ) echo "Swarm creation cancelled."; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

## Read the file to generate our user data that will be run when the Droplet is first created
DO_USER_DATA=$(cat ./user-data.sh)
DO_USER_DATA="${DO_UFW_OPTION}${DO_USER_DATA}"

# Credit for this approach: https://www.shellscript.sh/tips/spinner/
spin()
{
  spinner="/|\\-/|\\-"
  while :
  do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 1
    done
  done
}

printf "\n\n%s\n" "Beginning to create the first Droplet... this might take a little while"

# Start the Spinner and make a note of its Process ID (PID):
spin &
SPIN_PID=$!

# Credit to https://www.putorius.net/using-trap-to-exit-bash-scripts-cleanly.html
function egress {
  # Kill it by PID and don't show any output or the error if it's already killed. (https://stackoverflow.com/a/5722850)
  kill -9 $SPIN_PID > /dev/null 2>&1
  wait $SPIN_PID > /dev/null 2>&1
  echo "Last minute clean-up finished."
}

# Show spinner for period of seconds. Defaults to 10
function spinAndSleep {
  SLEEP_TIME=${1:-10}
  SLEEP_MESSAGE=${2:-""}

  echo $SLEEP_MESSAGE
  echo "Sleeping $SLEEP_TIME before continuing."
  # Start the Spinner and make a note of its Process ID (PID):
  spin &
  SPIN_PID=$!

  sleep ${SLEEP_TIME}s

  kill $SPIN_PID && wait $SPIN_PID > /dev/null 2>&1
  echo "Nap time's over. Back to work."
}

# Trap the spinner on any signal to clean it up.
trap egress EXIT

## Create the first host - this one will init the Swarm.
## We enable monitoring, backups, and private networking
DROPLET_ID=$( doctl compute droplet create $DO_DROPLET_NAME-0 --size $DO_SIZE --image $DO_IMAGE_NAME --region $DO_REGION --ssh-keys="$DO_SSH_IDS" --user-data="$DO_USER_DATA" $DO_BACKUP_OPTION --enable-monitoring --enable-private-networking --tag-names="$DO_TAGS,manager" --wait --format "ID" --no-header )

# kill the spinner now:
kill $SPIN_PID && wait $SPIN_PID > /dev/null 2>&1

echo "First Swarm Manager Created: $DROPLET_ID"

echo "Retrieving Host IPs"

## Get public and private IP from Droplet. While doable in one call, this is a little clearer and less fragile
export HOST_PRIVATE_IP=$( doctl compute droplet get $DROPLET_ID --format "PrivateIPv4" --no-header )
export HOST_PUBLIC_IP=$( doctl compute droplet get $DROPLET_ID --format "PublicIPv4" --no-header )
echo "Host IPs retrieved: $HOST_PRIVATE_IP, $HOST_PUBLIC_IP"

echo "Sleeping during housecleaning"

## take a breather - sometimes we try to SSH too soon
sleep 60s

printf "\n%s\n\n" "Back to work, initing the Swarm"

n=0
until [ $n -ge 10 ]
do
  echo "Confirming access to Docker daemon"
  ## Run initial SSH command to add key and init swarm - More on the host key checking here: http://manpages.ubuntu.com/manpages/bionic/en/man5/ssh_config.5.html
  ssh -o StrictHostKeyChecking=accept-new root@$HOST_PUBLIC_IP docker info && break
  n=$[$n+1]
  ## If it failed, try to sleep, before retrying
  echo "Attempt $n failed. Sleeping before retry"
  sleep 10s
done

n=0
until [ $n -ge 10 ]
do
  echo "Attempting to init Swarm"
  ## Run initial SSH command to add key and init swarm - More on the host key checking here: http://manpages.ubuntu.com/manpages/bionic/en/man5/ssh_config.5.html
  ssh -o StrictHostKeyChecking=accept-new root@$HOST_PUBLIC_IP docker swarm init --advertise-addr $HOST_PRIVATE_IP && break
  n=$[$n+1]
  ## If it failed, try to sleep, before retrying
  echo "Attempt $n failed. Sleeping before retry"
  sleep 30s
done

## Get the Manager Join Token
echo "Getting the manager join token"
SWARM_MANAGER_JOIN_TOKEN=$(ssh root@$HOST_PUBLIC_IP docker swarm join-token -q manager)

## If we're creating workers too, get the worker join token
if [ "$DO_WORKER_COUNT" -ge 1 ]; then
  echo "Getting the worker join token"
  SWARM_WORKER_JOIN_TOKEN=$(ssh root@$HOST_PUBLIC_IP docker swarm join-token -q worker)
fi

## If we're creating more than 1 manager, loop to create and add them to the Swarm
DO_MANAGERS_MORE=`expr $DO_MANAGER_COUNT - 1`
if [ "$DO_MANAGERS_MORE" -gt 1 ]; then

  printf "\n%s\n\n" "Beginning to create managers"

  for manager in $( seq 1 $DO_MANAGERS_MORE ); do
    echo "Creating another manager: $DO_DROPLET_NAME-${manager}"
    HOST_PUBLIC_IP=$( doctl compute droplet create $DO_DROPLET_NAME-${manager} --size $DO_SIZE --image $DO_IMAGE_NAME --region $DO_REGION --ssh-keys="$DO_SSH_IDS" --user-data="$DO_USER_DATA" $DO_BACKUP_OPTION --enable-monitoring --enable-private-networking --tag-names="$DO_TAGS,manager" --wait --format "PublicIPv4" --no-header )
    echo "Manager created. Sleeping during housecleaning"
    ## take a breather
    sleep 30s

    n=0
    until [ $n -ge 10 ]
    do
      echo "Attempting to join Swarm"
      ## Add keys and join swarm
      ssh -o StrictHostKeyChecking=accept-new root@$HOST_PUBLIC_IP docker swarm join --token $SWARM_MANAGER_JOIN_TOKEN $HOST_PRIVATE_IP:2377 && break
      n=$[$n+1]
      ## If it failed, try to sleep, before retrying
      echo "Attempt $n failed. Sleeping before retry"
      sleep 30s
    done

  done

  printf "\n%s\n\n" "Managers completed"
fi

## Follor same approach to create workers, if necessary
if [ "$DO_WORKER_COUNT" -ge 1 ]; then

  printf "\n%s\n\n" "Beginning to create workers"

  DO_WORKER_COUNT=`expr $DO_MANAGERS_MORE + $DO_WORKER_COUNT`
  for worker in $( seq $DO_MANAGER_COUNT $DO_WORKER_COUNT ); do
    echo "Creating a worker: $DO_DROPLET_NAME-${worker}"
    HOST_PUBLIC_IP=$( doctl compute droplet create $DO_DROPLET_NAME-${worker} --size $DO_SIZE --image $DO_IMAGE_NAME --region $DO_REGION --ssh-keys="$DO_SSH_IDS" --user-data="$DO_USER_DATA" $DO_BACKUP_OPTION --enable-monitoring --enable-private-networking --tag-names="$DO_TAGS,worker" --wait --format "PublicIPv4" --no-header )

    echo "Worker created. Sleeping during housecleaning"
    sleep 30s

    n=0
    until [ $n -ge 10 ]
    do
      echo "Attempting to join Swarm"
      ssh -o StrictHostKeyChecking=accept-new root@$HOST_PUBLIC_IP docker swarm join --token $SWARM_WORKER_JOIN_TOKEN $HOST_PRIVATE_IP:2377 && break
      n=$[$n+1]
      echo "Attempt $n failed. Sleeping before retry"
      sleep 30s
    done

  done

  printf "\n%s\n\n" "Workers completed"
fi

## Unset the environment variables we set
unset HOST_PRIVATE_IP
unset HOST_PUBLIC_IP

printf "\n%s\n\n" "Woohoo! All done. The $DO_DROPLET_NAME Swarm is up and running"