# Udagram Project

Terraform code for deploying the Cloud DevOps Engineer project #2.

## Requires

```
 terraform >= 0.13
```

## Running

You must have a preconfigured AWS Access ID and Secret Key in order to run the scripts.

```bash
# This will download the necessary modules and providers.
terraform init

# We now will plan out our deployment
terraform plan -out ./tfplan

# Apply the plan we just generated
terraform apply ./tfplan
```

## Output

On deployment the scripts will output the DNS name of the Elastic Load Balancer.

It might take a few minutes for the site to come up fully, so please be patient.