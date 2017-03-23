# Running Docker 
# Containers on AWS

![](images/docker-swarm.png)

### Philipp Garbe
Docker Captain

@pgarbe

-
### Goal of the workshop

Step-by-step through the process of setting up Docker Swarm from scratch on AWS. 


---
### Requirements

-
### Bring your own laptop
<!--![](images/laptop.png)-->

-
### Have your own AWS account 
(Free Tier, https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)

-
### No Account
I have no account, what yet?

-
### Install Docker
For Mac: https://www.docker.com/docker-mac  
For Windows: https://www.docker.com/docker-windows

```bash
$ docker version
Client:
 Version:      17.03.0-ce
 ...
```

-
### Clone Repsoitory


```bash
$ git clone git@github.com:pgarbe/containers_on_aws_workshop.git
$ cd containers_on_aws_workshop/files
```

-
### Build our workshop container

```bash
$ docker build -t dog2017 .
$ docker run -it -v ~/.aws:/.aws -v .:/workshop dog2017

# Inside container
$ cd workshop
$ aws --version
aws-cli/1.11.63 Python/3.6.0 Linux/4.9.12-moby botocore/1.5.26
```

-
### Setup credentials
* Open https://console.aws.amazon.com/iam/
* Create user "dog2017"
* Assign group "AdminAccess"

-
### Configure your credentials

```
$ aws configure
AWS Access Key ID []: xxx
AWS Secret Access Key []: xxx
Default region name []: eu-west-1
Default output format []: json

$ aws iam list-users
{
    "Users": []
}

```


-
### Setup ssh key
* Open https://eu-west-1.console.aws.amazon.com/ec2/v2/home#KeyPairs:sort=keyName
* Create Key Pair
* Download *.pem file into `files` folder

```bash
chmod 400 ~/<your key file>.pem
eval $(ssh-agent)
ssh-add <your key file>.pem
```

-
### Define stack name

Replace "todo" with your username

```bash
#!/bin/bash -e
stackname=todo-docker-swarm

aws s3api create-bucket --bucket $stackname
aws s3 cp . s3://$stackname/ --recursive --include "*.yaml"
...
```

***
deploy.sh

---
### Infrastructure as Code with CloudFormation


-
### What is Infrastructure as Code?
> "Infrastructure as code is the approach to defining computing and network infrastructure through source code that can then be treated just like any software system." (Martin Fowler)

-
### What is Infrastructure as Code?
* Versioning
* Reproducable Builds
* Continuous Delivery

-
### What is CloudFormation?
* A managed service by AWS
* Manage resources based on config
* Takes care of dependencies

-
### CloudFormation Concepts
* Parameters, Resources, Outputs
* Intrinsic functions (like If, Split, Join)
* Import / Export

-
### Example
```yaml
Parameters:
  KeyName:
    Description: Name of an existing EC2 KeyPair to enable SSH access to the instance
    Type: String

Resources:
  ElasticLoadBalancer:
    Type: AWS::ElasticLoadBalancing::LoadBalancer
    Properties:
      AvailabilityZones: !GetAZs AWS::Region
        ...

Outputs:
  InstallURL:
    Value: !Sub http://${ElasticLoadBalancer.DNSName}/wp-admin/install.php
    Description: Installation URL of the WordPress website
```


---
### Basic VPC Setup

-
### Hands on: Create our first stack

```yaml
Resources:
  Vpc:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3-eu-west-1.amazonaws.com/widdix-aws-cf-templates/vpc/vpc-3azs.yaml
```

***
stack.yaml

-
### Hands on: Deploy

```
$ ./deploy.sh 
```

-
### VPC Explained

![](images/vpc-3azs.png)

***
Source: https://github.com/widdix/aws-cf-templates


-
### Bastion Host
Enable the following parts

```yaml
Resources:
  Vpc:
    ...

  Bastion:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://s3-eu-west-1.amazonaws.com/widdix-aws-cf-templates/vpc/vpc-ssh-bastion.yaml
      Parameters:
        ParentVPCStack: !Select [1, !Split ['/', !Ref Vpc]]
        KeyName: !Ref KeyName
```

***
stack.yaml

-
### Deploy Bastion Host

```
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name>
```

-
### Bastion Host Explained

![](images/vpc-ssh-bastion.png)

***
Source: https://github.com/widdix/aws-cf-templates

-
### SSH to Bastion Host

```
$ ssh -A ec2-user@<Public IP of bastion host>
```


---
### Docker
![](images/docker.png)


-
### Add new stack for security groups
Enable the following parts

```yaml
Resources:
  ...

  SecurityGroups:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/securitygroups.yaml
      Parameters:
        ParentVPCStack: !Select [1, !Split ['/', !Ref Vpc]]
        ParentSSHBastionStack: !Select [1, !Split ['/', !Ref Bastion]]
```

***
stack.yaml


-
### Deploy our stack

```
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name>
             
```

-
### Security Groups Explained

* Act as a virtual firewall 
* Controls inbound and outbound traffic
* Examples: LoadBalancer, SSH

-
### Add new stack for Swarm Manager
Enable the following parts

```yaml
Resources:
  ...

  Manager:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/manager.yaml
      Parameters:
        ParentVPCStack: !Select [1, !Split ['/', !Ref Vpc]]
        KeyName: !Ref KeyName
        Version: !Ref Version
        SecurityGroups: !GetAtt SecurityGroups.Outputs.SecurityGroups

        # JoinToken: !Ref SwarmManagerJoinToken
        # DesiredInstances: !If [HasManagerJoinToken, !Ref DesiredManagerInstances, 1]
        # JoinTokenKmsKey: !GetAtt Kms.Outputs.SwarmTokenKeyArn

```

***
stack.yaml


-
### Deploy our stack

```
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name>
             
```

-
### Review manager.yaml
* AutoScaling Group
* LaunchConfiguration
* cfn-init

-
### Validate your stacks


Open https://eu-west-1.console.aws.amazon.com/cloudformation

-
### Summary

* Defined our own VPC 
* Created Bastion Host for SSH
* AutoScaling Group for Manager Nodes
* EC2 machine (Ubuntu) with Docker 


---
### Docker Swarm

![](images/docker-swarm.png)


-
### The Challenge
* To create Swarm we need Join Tokens
* To generate Join Tokens we need Swarm

- 
### Solving the Challenge
1. Create stack with one EC2 machine
2. Initialize Swarm
3. Use Join-Tokens as stack parameters
4. Update stack


-
### Add new stack for Swarm Manager
Enable the following parts

```yaml
Resources:
  Manager:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/manager.yaml
      Parameters:
        ...

        JoinToken: !Ref SwarmManagerJoinToken
        DesiredInstances: !If [HasManagerJoinToken, !Ref DesiredManagerInstances, 1]
        # JoinTokenKmsKey: !GetAtt Kms.Outputs.SwarmTokenKeyArn
```

***
stack.yaml


-
### Init or Join?

```yaml
  LaunchConfiguration:
    Type: AWS::AutoScaling::LaunchConfiguration
    Metadata:
      AWS::CloudFormation::Init:
        configSets:
          default:
            !If 
            - HasSwarmJoinToken
            - [docker-ubuntu, swarm-join]
            - [docker-ubuntu, swarm-init]
```
***
manager.yaml


-
### Initialize Swarm

```yaml
LaunchConfiguration:
  Type: AWS::AutoScaling::LaunchConfiguration
  Metadata:
    AWS::CloudFormation::Init:
      docker-ubuntu:
      ...

      swarm-init:
        commands:
          'a_join_swarm':
            command: 'docker swarm init'

          'b_swarm_healthcheck':
            command: 'docker node ls'
```

***
manager.yaml

-
### Join Manager Nodes 
Find out current EC2 instance-id and AutoScaling Group.

```yaml
swarm-init: ...

swarm-join:
  commands:
    'a_join_swarm':
      command: !Sub | 
        INSTANCE_ID=$(wget -q -O - http://instance-data/latest/meta-data/instance-id)
        ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
                  --instance-ids $INSTANCE_ID \
                  --region ${AWS::Region} \
                  --query AutoScalingInstances[].AutoScalingGroupName \
                  --output text)
```

***
manager.yaml

-
### 
Loop through all available EC2 instances

```yaml
swarm-join:
  commands:
    'a_join_swarm':

        ...

        for ID in $(aws autoscaling describe-auto-scaling-groups \
                    --auto-scaling-group-names $ASG_NAME \
                    --region ${AWS::Region} \
                    --query AutoScalingGroups[].Instances[].InstanceId \
                    --output text);
        do

          ...

        done

```

***
manager.yaml

-
### 
Try to join an existing manager node

```bash
    do
      # Ignore "myself"
      if [ "$ID" == "$INSTANCE_ID" ] ; then
          continue;
      fi
      IP=$(aws ec2 describe-instances \
            --instance-ids $ID \
            --region ${AWS::Region} \
            --query Reservations[].Instances[].PrivateIpAddress \
            --output text)

      if [ ! -z "$IP" ] ; then
        echo "Try to join swarm with IP $IP"

        # Join the swarm; if it fails try the next one
        docker swarm join \
          --token ${JoinToken} $IP:2377 && break || continue
      fi

    done
```

***
manager.yaml


-
Make sure the node successfully joined the swarm cluster!

```yaml
        swarm-join:
          commands:
            'a_join_swarm':
            ...

            'b_swarm_healthcheck':
              command: 'docker node ls'
```

***
manager.yaml


-
Create one EC2 instance and initialize swarm cluster!

```bash
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name>
```

</br>  
SSH into swarm manager (via bastion host)

```bash
$ ssh -A ec2-user@<Public IP of bastion host>
$ ssh ubuntu@<Private IP of manager node>
```

-
Get the swarm join tokens and copy them 

```bash
$ docker swarm join-token manager --quiet
$ docker swarm join-token worker --quiet
```
</br>  


-
### Summary

* Automatic initialization of Docker Swarm
* Manual copy of join tokens
* Automatic join of additional manager nodes



---
## Secure your tokens

-
### KMS
Enable the following parts

```yaml
Resources:

  Kms:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/kms.yaml
```

***
stack.yaml


-
### Update stack
* The KMS key needs to be created first, before we can encrypt the join token
* Copy ARN of KMS key from Stack output.


```bash
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name> 
```


-
Forward KMS Arn to manager stack

```yaml
Resources:
  Manager:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/manager.yaml
      Parameters:
        ...

        JoinTokenKmsKey: !GetAtt Kms.Outputs.SwarmTokenKeyArn

```

***
stack.yaml


-
Add new parameter to manager stack

```yaml
Parameters:
  ...

  JoinTokenKmsKey:
    Description: 'KMS key to decrypt swarm join tokens'
    Type: String
```

***
manager.yaml

-
### Allow instance role to decrypt 
Enable the following policy

```yaml
Resources:
  ...
  IAMRole:
    Type: 'AWS::IAM::Role'
    Properties:
      ...
      Policies:
      - PolicyName: kms
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
          - Effect: Allow
            Action:
            - 'kms:Decrypt'
            - 'kms:DescribeKey'
            Resource:
            - !Ref JoinTokenKmsKey

```

***
manager.yaml

-
Decrypt join token

```yaml
swarm-join:
  commands:
    'a_join_swarm':
      command: !Sub | 
        echo -n "${JoinToken}" | base64 --decode > ciphertextblob
        JOIN_TOKEN=$(aws kms decrypt \
                      --region ${AWS::Region} \
                      --ciphertext-blob fileb://ciphertextblob \
                      --query Plaintext \
                      --output text | base64 --decode)
        
        do

          # docker swarm join \
          #  --token ${JoinToken} $IP:2377 && break || continue

          docker swarm join \
            --token $JOIN_TOKEN $IP:2377 && break || continue
        done

```

***
manager.yaml


-
### Update stack

```bash
manager_token=$(aws kms encrypt \
                --key-id <KmsKeyArn> \
                --plaintext <SwarmManagerJoinToken> \
                --output text \
                --query CiphertextBlob)

$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name> \
              ParameterKey=SwarmManagerJoinToken, \
              ParameterValue=$manager_token
```

-
### Summary

* Created KMS key for encryption and decryption
* Simple policy who can use kms key
* Encrypted join tokens with KMS
* Allowed instance role to decrypt tokens



---
## Worker Nodes

-
### Worker Stack
Enable the following parts

```yaml
Resources:

  Worker:
    Condition: HasWorkerJoinToken
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/worker.yaml
      Parameters:
        ParentVPCStack: !Select [1, !Split ['/', !Ref Vpc]]
        SwarmManagerAutoScalingGroup: !GetAtt Manager.Outputs.AutoScalingGroup
        SecurityGroup: !GetAtt SecurityGroups.Outputs.SecurityGroup
        JoinToken: !Ref SwarmWorkerJoinToken
        JoinTokenKmsKey: !GetAtt Kms.Outputs.SwarmTokenKeyArn
        KeyName: !Ref KeyName
        DesiredInstances: !Ref DesiredWorkerInstances
        Version: !Ref Version
```

***
stack.yaml

-
### Update stack

```bash
worker_token=$(aws kms encrypt \
                --key-id <KmsKeyArn> \
                --plaintext <SwarmWorkerJoinToken> \
                --output text \
                --query CiphertextBlob)

$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name> \
              ParameterKey=SwarmManagerJoinToken,ParameterValue=$manager_token \
              ParameterKey=SwarmWorkerJoinToken,ParameterValue=$worker_token
```


-
### Review worker.yaml
* Join Swarm
* Healthcheck


-
### Summary

* Very similar to manager stack
* Worker need IP of managers to join the cluster
* Separate stacks to scale independently
* Use different KMS keys for managers and workers



---
## Deploy sample application
(Of course, the famous voting app)


-
### Run app locally

```bash
$ docker swarm init
$ docker stack create --compose-file ./files/docker-stack.yaml voting-app
```
</br>

* Voting: http://localhost:5000
* Results: http://localhost:5001
* Visualizer: http://localhost:8080


-
### Deploy application
First, ssh into a manager node

```bash
curl https://raw.githubusercontent.com/pgarbe/
     containers_on_aws_workshop/master/files/docker-stack.yml
     > docker-stack.yaml

docker stack deploy -c docker-stack.yaml voting-app
```

</br>

Did we miss something?

-
### Load balancer

* Elastic LoadBalancer
  - Static port mapping
  - Layer 4

* Application LoadBalancer
  - Dynamic port mapping
  - Layer 7

-
### Application LoadBalancer

![](images/alb.png)


-
### Load Balancer
Enable the following parts

```yaml
Resources:
  Manager:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/manager.yaml
      Parameters:
        ...
        TargetGroups: !GetAtt LoadBalancer.Outputs.TargetGroups

  LoadBalancer:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub https://s3.amazonaws.com/${AWS::StackName}/loadbalancer.yaml
      Parameters:
        ParentVPCStack: !Select [1, !Split ['/', !Ref Vpc]]
```

***
stack.yaml

-
### Final deployment

```bash
$ ./deploy.sh ParameterKey=KeyName,ParameterValue=<your key name> \
              ParameterKey=SwarmManagerJoinToken,ParameterValue=$manager_token \
              ParameterKey=SwarmManagerJoinToken,ParameterValue=$worker_token
```
=> Check outputs of loadbalancer stack for DNS name




---
## Summary

-
You should now be able to

* Create and update nested CloudFormation stacks
* Initialize Docker Swarm
* Scale manager and worker nodes
* Secure join tokens with KMS keys
* Deploy Docker stacks on Swarm
* Configure LoadBalancer to access services

-
# Thank You

Philipp Garbe  
@pgarbe

http://garbe.io

</br>

***
What should be improved? Let me know!  

</br>

dog2017@garbe.io


