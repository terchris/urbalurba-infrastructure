# Dev and Test Package

This package contains the tools and services for developing and testing software. The dev and test stack is set up to be as close to the production stack as possible using open source software.

The goal is to provide a complete development environment for building, testing, and deploying software.

The stack includes ArgoCD for managing the deployment of the software.

The dev and test pacage provides the deployment and the services (databases +++) to support the development of the software.

Enabling rapid development, testing and deployment of the software.

## Development environment

The development environment builds on the [devcontainer-toolbox project](https://github.com/terchris/devcontainer-toolbox).

The devcontainer-toolbox project provides a set of tools and services to develop sw using a vide selection of programming languages and frameworks:

- Python
- Node.js
- Java
- C#
- Go
- PHP

## Development templates

The [urbalurba-dev-templates](https://github.com/terchris/urbalurba-dev-templates) repository provides a set of templates for developing software using the devcontainer-toolbox project.

Here you will find sample programs that demonstrates the development of backend and frontend applications. All examples are implemented in TypeScript, Python, Java, C#, Go and PHP.

The templates are designed to be used with the [devcontainer-toolbox project](https://github.com/terchris/devcontainer-toolbox).

Just type ´.devcontainer/dev/dev-template.sh´ in the devcontainer-toolbox and select a template. And you are ready to go.

## Deployment

The templates are designed so that when you push to GitHub your code will be built, containerized and deployed to the kubernetes cluster on your local machine.

The deployment is done using ArgoCD. And once deployed you can open your browser and test the application.

## Database Setup

- See [MySQL Setup Documentation](./package-datascience.md#mysql-setup-documentation) for details on deploying and verifying MySQL in the cluster.

