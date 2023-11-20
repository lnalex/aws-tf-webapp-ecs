# Nginx hosted on ECS

Single region HA deployment of a HTTP based application container image on ECS with service connect and autoscaling.

## Notes

Terraform is executed from a pipeline or adminsitrative role, assumes a deploy role in target accounts to provision and manage resources. TF state is stored in the administrative/pipeline account. Separating environments into different AWS accounts reduces the blast radius in the event of an environment account being compromised (e.g. via application exploit).

### Pipeline/administrative account

Contains encrypted S3 bucket and DDB table for TF state and locking for each environment

The role deploying the infrastructure should have `sts:AssumeRole` permissions to assume a deploy role inside each environment account.

A separate administrative role can be used for each env with restricted access to the respective workspace state and assume role permissions if needed.
See https://developer.hashicorp.com/terraform/language/settings/backends/s3#protecting-access-to-workspace-state on configuring IAM permissions to lock this down.

### Environment accounts

A separate AWS account for each environment that contains deployed resources.

Each account should contain a deploy role that the administrative/pipeline role can assume to provision resources inside that account.

### Route53 account

Terraform will provision an ACM certificate in the environment account and Route53 records in an existing Route53 hosted zone to validate the certificate, as well as an alias record pointing to the ALB for the specified domain name.

The Route53 hosted zone should reside in a separate account. Terraform will assume a provided role set via the `var.cert_config.route53_role` value to create Route53 records. 

The cross account role needs to have at least the following permissions to function:

```
route53:GetChange
route53:ListResourceRecordSets
route53:GetHostedZone
route53: ChangeResourceRecordSets
```

## Bootstrapping

Only needs to be done once

### Create the remote backend bucket and lock table for Terraform

1. Set working dir to `bootstrap/`
2. Run `terraform init` and configure variables in `remote.tfvars`
3. Run `terraform apply -var-file remote.tfvars`

You can alternatively manually create these resources as well as a one time process.

### Setup

1. Set working directory to top level
2. Configure backend values for `provider.tf` accordingly and run `terraform init`
3. Create deploy roles in environment accounts and Route53 account as needed with appropriate permissions depending on which resources you need to provision with Terraform
4. Create Terraform workspaces with `terraform workspace new <ENV_NAME>`
5. Create and configure values for the `tfvars` file for the environment under `environments/<ENV_NAME>.tfvars`

## Deploying

Run helper script `deploy.sh <ENV_NAME>` or manually switch to the workspace and run `terraform apply -var-file ...`
