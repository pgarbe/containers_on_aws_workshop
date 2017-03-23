Running Docker Containers on AWS
================================

## Abstract
Running containers locally has been made very easy by Docker with tools like Docker for Mac or Windows. With Docker Swarm a group of Docker engines can be turned into a virtual Docker Engine providing native clustering capabilities.

But how do you setup Docker Swarm cluster on AWS? What is necessary to deploy your application to the swarm?

In this workshop, Philipp guides you step-by-step through the process of setting up Docker Swarm from scratch. He also shows how to deploy and update applications based on Docker Compose v3. Principals like immutable infrastructure and configuration as code will influence the entire process as CloudFormation plays an important role.

## Agenda:
I. Basic Setup (45 min)
* Local Requirements
* Immutable Infrastructure with CloudFormation
* Basic VPC Setup

II. Docker (30 min)
* Run Docker on EC2 (VMs)
* Scale with AutoScaling Groups

BREAK (15 min)

III. Docker Swarm (60 min)
* Setup Manager Nodes
* Secure Swarm Tokens
* Automatically join Worker Nodes

IV. Deploy Applications (30 min)
* Deploy sample application

## Who should join?
* Everyone who wants to setup and run Docker Swarm on AWS
* Some experience with AWS or Docker is recommended (but not required)

## Prerequisites:
* Bring your own laptop
* Have your own AWS account (Free Tier, https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
* Install AWS Cli (http://docs.aws.amazon.com/cli/latest/userguide/installing.html)


## How to run the presentation

```bash
docker run -ti -d --name slidefire -v `pwd`/images:/opt/presentation/images -v  `pwd`/slidefire:/opt/presentation/lib/md -v `pwd`/build:/build -p 8000:8000 pgarbe/slidefire
```