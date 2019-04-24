# Setting Up a New Docker Swarm on DigitalOcean <!-- omit in toc -->

As the name suggestions, this is a script for quickly creating a Docker Swarm on DigitalOcean. It enables you to configure the size of the Droplets, the number of managers and workers, and more. Droplets are based on DigitalOcean's [One-Click Docker image](https://marketplace.digitalocean.com/apps/docker).

The aim of this script is to be straightforward - a (relatively) simple, mostly automated way to get started setting up a Swarm. If you're looking for a more robust, configurable solution to infrastructure scripting, I recommend taking the time to learn [Terraform](https://www.terraform.io/).

## Table of Contents <!-- omit in toc -->

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Options](#options)
- [Questions](#questions)
- [Contributing](#contributing)

## Prerequisites

While the aim is to keep this simple, there are a few requirements in order to use this script - they're listed here, along with links to the corresponding DigitalOcean guides:

- **DigitalOcean account**
  Shameless plug here: [$100 promo with referral](https://m.do.co/c/8acbd6928587).
- **SSH credentials added to your account** ([DO Guide](https://www.digitalocean.com/docs/droplets/how-to/add-ssh-keys/))
  These provide access to the Droplets and are used by the script to init the Swarm, once the Droplets are created.
- **Personal Access Token for the DigialOcean API** ([DO Guide](https://www.digitalocean.com/docs/api/create-personal-access-token/)).
  This is used by DigitalOcean's command-line client to create the Droplets and get information about your account
- **Install DigitalOcean's official command-line client, `doctl`** ([DO Guide](https://github.com/digitalocean/doctl#installing-doctl))
  This will do most of the heavily lifting. It's an invaluable tool if you have an account with DigitalOcean, and necessary for this script. Their full `doctl` tutorial is [here](https://www.digitalocean.com/community/tutorials/how-to-use-doctl-the-official-digitalocean-command-line-client).

## Getting Started

After completing the [prerequisites](#prerequisites) listed above, here are the steps for using this script:

1. Clone this repository, and navigate into it.
   ```
   git clone git@github.com:mjclemente/do-swarm-create.git
   cd do-swarm-create
   ```
2. Configure the [options](#options) via environment variables. For example:
   ```
    export DO_ENABLE_BACKUPS=false
    export DO_REGION=sfo2
   ```
3. Run the `create-hosts.sh` script.
   ```
   ./create-hosts.sh
   ```
4. Confirm Swarm options. Enter `yes` to proceed or `no` to cancel.
5. Depending on the options you've set, Swarm creation could take some time. Information about what is being done will be logged in the console as it progresses.

## Options

The options for this script are configured via environment variables. Here they are, with their default values:

- **`DO_DROPLET_NAME`**
  *Default*: swarm-node
  Name of the Droplets that are created, followed by incrementing numbers, i.e. `swarm-node-2`
- **`DO_SIZE`**
  *Default*: s-1vcpu-1gb ([$5/mo](https://www.digitalocean.com/pricing/#Compute))
  Size of the Droplets being created. You can get a list of available options by running `doctl compute size list`
- **`DO_ENABLE_BACKUPS`**
  *Default*: true
  Enables automatic weekly backups of the Droplets. This adds 20% to price. More about backups can be found [here](https://www.digitalocean.com/docs/images/backups/overview/).
- **`DO_ENABLE_UFW`**
  *Default*: true
  The UFW firewall is automatically enabled and configured for Docker Swarm use. If you plan on using a DigitalOcean firewall, you'll likely want to set this option to `false`, so that you don't need to manage two firewalls.
- **`DO_REGION`**
  *Default*: nyc1
  Region in which the Droplet is created. Options can be seen by running `doctl compute region list`
- **`DO_TAGS`**
  *Default*: $DO_DROPLET_NAME,(master|worker)
  Custom labels for Droplets. Helpful for filtering in when using the DO API, or applying Firewall or Load Balancer rules. By default, the Droplet name variable is applied as a tag to all nodes in the Swarm, but you can override this. The `master` or `worker` tags are always included.
- **`DO_MANAGER_COUNT`**
  *Default*: 3
  Number of Swarm managers that should be created.
- **`DO_WORKER_COUNT`**
  *Default*: 0
  Number of Swarm workers that should be created.
- **`DO_SSH_IDS`**
  *Default*: All SSH IDs added to your DO account
  List of SSH keys that should be added to the Droplets, referenced either via their DigitalOcean resource Id, or their fingerprint. If you don't want all the SSH keys in your DO account included, use the command `doctl compute ssh-key list` to retrieve your SSH keys and selectively add them to this variable.

## Questions
For questions that aren't about bugs, feel free to hit me up on Twitter: [@mjclemente84](https://twitter.com/mjclemente84). You'll likely get a much faster response than creating an issue here.

## Contributing
:+1::tada: First off, thanks for taking the time to contribute! :tada::+1:

Before putting the work into creating a PR, I'd appreciate it if you opened an issue. That way we can discuss the best way to implement changes/features, before work is done.

Changes should be submitted as Pull Requests on the `develop` branch.