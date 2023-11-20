# Nginx container app hosted on ECS

Single region HA deployment of a HTTP based application container image on ECS with service connect and autoscaling.

## Notes

Terraform is executed from a pipeline or adminsitrative role, which then assumes a deploy role in target accounts to provision and manage resources in those accounts. Terraform state is stored in the administrative/pipeline account.

Separating environments into different AWS accounts reduces the blast radius in the event of an environment account being compromised (e.g. via application exploit).

### Pipeline/administrative account

Contains encrypted S3 bucket and DDB table for Terraform state and locking for each environment

The role deploying the infrastructure should have `sts:AssumeRole` permissions to assume a deploy role inside each environment account.

A separate administrative role can be used for each env with restricted access to the respective workspace state and assume role permissions if needed.
See https://developer.hashicorp.com/terraform/language/settings/backends/s3#protecting-access-to-workspace-state on configuring IAM permissions to lock this down.

### Environment accounts

A separate AWS account for each environment (e.g. `dev`, `staging`, `prod`) that contains deployed resources.

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

### Create the remote backend bucket and lock table for Terraform

Only needs to be done once to setup resources for Terraform remote state.

1. Set working dir to `bootstrap/`
2. Run `terraform init` and configure variables in `remote.tfvars`
3. Run `terraform apply -var-file remote.tfvars`

You can alternatively manually create these resources as well as a one time process.

### Setup configuration

1. Set working directory to top level
2. Configure backend values for `provider.tf` accordingly and run `terraform init`
3. Create IAM roles in environment accounts and Route53 account as needed with appropriate permissions depending on which resources you need to provision with Terraform
4. Create Terraform workspaces with `terraform workspace new <ENV_NAME>` for each target environment (e.g. `dev`, `staging`, `prod`)
5. Create and configure values for the `tfvars` file for each environment under `environments/<ENV_NAME>.tfvars`

## Deploying

Run the helper script `deploy.sh <ENV_NAME>` or manually switch to the environment workspace with `terraform workspace select <ENV_NAME>` and run `terraform apply -var-file ...` to deploy to the environment.


## Deployed resources

Terraform will deploy the following resources:

- VPC
    - Public subnets are provisioned for each enabled AZ with an IGW default route
    - NAT GWs with EIPs are provisioned into each public subnet, one per AZ as per best practices
    - Private subnets are provisioned for each enabled AZ, with a default route to the local NAT GW


- ECS cluster
    - Container insights is enabled for observability
    - ECS service connect is enabled for service discovery/mesh connectivity as well as additional network observability
    - A Cloud Map namespace is provisioned for ECS service connect

- ECS capacity provider
    - ASG, LT, IAM roles, policies, and instance profiles for ECS container instances are provisioned
    - SSM is enabled to allow shell access to container instances, no SSH keypair is configured for security
    - A default capacity provider backed by the ASG is configured to the cluster with managed scaling
    - Container instances are provisioned into private subnets with no ingress traffic permitted

- ECS service
    - Task definition for the container is configured with application logging sent to a CloudWatch log stream
    - Tasks are provisioned with the awsvpc network mode to allow fine grained security group rules, which allow ingress traffic from the ALB only
    - ECS service connect is configured for the service
    - Task level autoscaling is enabled through Application Autoscaling with a target tracking policy
    - A task IAM role is provisioned and attached with no permissions by default. Additional permissions can be added to the role as needed.

- Application Load Balancer
    - ACM certificate for the HTTPS listener
    - Route53 records for the ACM certificate validation
    - Route53 alias record for the ALB
    - HTTP listener configured to redirect to HTTPS
    - HTTPs listener that forwards all traffic to the application container
    - Access logging is enabled and sent to an S3 bucket encrypted using AWS managed encryption keys
