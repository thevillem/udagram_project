# Udagram Project

Cloudformation templates for deploying the Cloud DevOps Engineer project #3.

## Requires

```
 awscli
```

## Running

You must have a preconfigured AWS Access ID and Secret Key in order to run the scripts.

```bash
# This will setup and configure our network stack to setup for server deployment.
aws cloudformation create-stack --stack-name udacity-network --template-body file://networks.yml --parameters file://network-parameters.json --region=us-east-2

# This will setup and configure our server stacks.
aws cloudformation create-stack --stack-name udacity-server --template-body file://servers.yml --parameters file://server-parameters.json --region=us-east-2 --capabilities CAPABILITY_IAM
```

## Cleaning Up
To remove the stacks, run the following commands in order to first remove the server stacks and then the network stacks.

```bash
# Deletes the udacity-server stack
aws cloudformation delete-stack --stack-name udacity-server --region=us-east-2

# Deletes the udacity-network stack
aws cloudformation delete-stack --stack-name udacity-network --region=us-east-2

```

