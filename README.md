### Introduction ###
---

This repository is desgined to extract countries information once a dya at 1am. It uses two API endpoints ot extract this data and then lands this data in its raw format in S3. Data in S3 is organised by the date of extraction. This application uses the Python requests library to retrieve data from API endpoints. When iterating through this extraction we use a Thredpool Executor in order to allow parrallel processing of these requests to improve performance. We then use boto3 to save these files in a json format to S3. It uses a Pytest framework for testing.

### Layout ###
---
This repository is hosted in AWS and as such there are many aspects to this repository
src : Holds the Dockerfile for creating an image, application code and testing suite
terraform : Holds the IaC for AWS infrastructure
scripts : Holds helper scripts for deployment of the repo
.github : Holds CICD yaml files for the deployment of this repo

### Design & Architecture ###
---
This applicaition is deployed using a variety of AWS resources

S3: Cost effective storage of data extracts
ECR: This is to save the Docker Image
ECS: Hosting containers and defining the task from the ECR image
Cloudwatch: Storing Logs and Scheduling of the Application through Cloudwatch Event Rules
IAM: Permissions and Roles for the execution of the application

### Setup ###
In order for this repoisitory to work you will need to install poetry, asdf and Terraform.

The repository works from a Makefile in order to make the use fo this repository easier.
Running 'make setup' from the CLI will install all of the dependencies of the repository.

You will also need to have AWS CLI and a .aws profile file on your local machine, this will allow you to access the TF backend state file and to access S3 to save the extract.
Running the make command to build the Docker container will then mount this .aws profile file to the Docker container.

### Working with the Repo ###

The repo is built with a Makefile to make it easier to work with on OS and Linux.
Running 'make help' will give you a list of commands that you can run with this repo.

Running locally
---
the Makefile allows you to run tests and the script locally with make commmands 'test', 'lint' and 'clean'
This requires AWS CLI to be able to assume an AWS role, this should always ben done with a dev account.

Docker
---
The Makefile also allows for you to build and run a docker container locally, by default the make command will mount an AWS profile named 'dev' from your .aws profile file.

Running 'make docker-clean' will destroy all docker infrastructure locally on your machine so make sure to run this when you are done developing locally.

### CICD ###

This repository uses Github Actions for its deployment allowing the infrastructure and the Docker image to be deployed in parallel. There are two workflows defined in this repository.

on-push: defined the CICD for when a PR is merged into main - Runs all testing and linting, TF apply and pushes the Docker image to ECR.
on-pull-request: defines what should be done when a PR targetting main has been created -  this runs some pre-commit hooks and testing,linting & TF plan.

