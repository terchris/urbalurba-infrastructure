# Readme Urbalurba Infrastructure

This is the readme for the Urbalurba Infrastructure.

## Overview

The goal of the Urbalurba Infrastructure is to provide a environment for developers, system admins and devops engineers that can be used to develop, test and deploy applications.

It is a full infrastructure stack that has the services that the cloud infrastructure providers (AWS, Azure, GCP) provide.

This is done by provisioning a full infrastructure that runs on a single machine like the developers laptop. The same infrastructure can be deployed to the cloud providers (AWS, Azure, GCP) or on-premises. So if the application works on the developers laptop then the same application will work in the cloud or on-premises.

The stack provides open source versions of the services that the cloud providers offer. It contains services like databases, message queues, monitoring, logging, etc.

## What is included?

- [AI package (OpenWebUI)](doc/package-ai.md) - Sets up ChatGPT like system that runs AI locally. Enables you to use AI on private documents with no need to worry about the privacy of the documents.

TODO: analyze  the doc folder and the markdown readme files there to create a overall readme for the infrastructure.

## Installation

### For Mac/Linux users:
The installation script will handle all prerequisites and installation in one go. It will:
1. Install Homebrew (if not present)
2. Install Rancher Desktop (which includes kubectl)
3. Download and install the Urbalurba Infrastructure

Run the following command to install:
```bash
curl -L https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/update-urbalurba-infra.sh -o update-urbalurba-infra.sh && chmod +x update-urbalurba-infra.sh && ./update-urbalurba-infra.sh
```

### For Windows users:
Windows installation will be added soon.

Notes:

- It solves the problem of "it works on my machine" 
- It is a full infrastructure stack that has the services that the cloud infrastructure providers (AWS, Azure, GCP) provide.
- It is a single machine that can be deployed to the cloud providers (AWS, Azure, GCP) or on-premises.
- It is a full infrastructure stack that can be used to develop, test and deploy applications.
- The developer has full control over the dev and test environment. Not needing any permissions in the cloud during development and test.
- The cloud infrastructure team dont need to provide any permissions in the cloud during development and test.



