# Install Rancher Desktop on Mac

## Prerequisites

Before installing Rancher Desktop, you need to have:

1. Rancher Desktop
2. kubectl (Kubernetes command-line tool)

### Install kubectl

You can install kubectl using one of these methods:

```bash
# Using Homebrew
brew install kubectl

# Or download directly from Kubernetes website
# Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/
```

## Install Rancher Desktop

Follow the instructions in the [official website](https://docs.rancherdesktop.io/getting-started/installation/#macos).

Or better use Homebrew to install it:

```bash
brew install --cask rancher
```

If you don't have Homebrew installed, you can install it from [here](https://brew.sh/).

## Configure Rancher Desktop

After installing Rancher Desktop, you need to configure it.

Accept the first screen and click on the `Next` button.

![Rancher Desktop - First screen](images/rancher-desktop-first-screen.png)

It takes a couple of minutes to download kubernetes and initialize it. When it is finished it says "Welcome to Rancher Desktop by SUSE".

We need to give the cluster some more memory. Click on the ´Preferences´ button. Then on ´Virtual Machine´.

I have a Macbook Air M2. It has 8 CPU cores and 16GB of RAM and I have found that i can give it half of the RAM and half of the CPU cores.

![Rancher Desktop - Preferences](images/rancher-desktop-preferences.png)

Optional settings:

- Mount Type: Select virtiofs as it is faster than the default (but you dont need to change it).
- Emulation: Select VZ as it is faster than the default (but you dont need to change it).

After that click on the `Apply` button and the kuberntetes will restart.












