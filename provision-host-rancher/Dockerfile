# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Create ansible user and set up sudo
RUN apt-get update && apt-get install -y sudo && \
    useradd -m -s /bin/bash ansible && \
    echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible && \
    chmod 0440 /etc/sudoers.d/ansible

# Install basic tools
RUN apt-get update && \
    apt-get install -y \
    apt-utils \
    sudo \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    vim \
    bash-completion \
    jq \
    iputils-ping \
    net-tools \
    dnsutils \
    netcat \
    traceroute \
    && rm -rf /var/lib/apt/lists/*

# Install yq for manipulating yaml files in scripts
RUN YQ_VERSION="v4.44.1" && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) \
        BINARY="yq_linux_amd64" \
        ;; \
      aarch64 | arm64) \
        BINARY="yq_linux_arm64" \
        ;; \
      *) \
        echo "Unsupported architecture: $ARCH" && \
        exit 1 \
        ;; \
    esac && \
    echo "Downloading yq version $YQ_VERSION for architecture $ARCH..." && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${BINARY}" && \
    chmod a+x /usr/local/bin/yq && \
    echo "Installed yq version:" && \
    /usr/local/bin/yq --version

# Create necessary directories
RUN mkdir -p /mnt/urbalurbadisk && \
    chown ansible:ansible /mnt/urbalurbadisk

# Switch to ansible user
USER ansible
WORKDIR /home/ansible

# Set up environment variables
ENV PATH="/home/ansible/.local/bin:${PATH}"

# Create required directories
RUN mkdir -p \
    ~/.local/bin \
    ~/.config \
    ~/.ssh

# Set working directory
WORKDIR /mnt/urbalurbadisk

# Copy entrypoint script for kubeconfig handling
COPY --chown=ansible:ansible entrypoint-copy-kubeconf.sh /entrypoint-copy-kubeconf.sh
USER root
RUN chmod +x /entrypoint-copy-kubeconf.sh
# Switch back to ansible user
USER ansible

# Use entrypoint script to handle kubeconfig setup
ENTRYPOINT ["/entrypoint-copy-kubeconf.sh"]

# Default command keeps container running
CMD ["tail", "-f", "/dev/null"]