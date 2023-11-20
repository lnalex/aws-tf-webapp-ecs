region = "ap-southeast-2"

# See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
container_instance_ami = "ami-07bf5e890fb20aba3"

network_config = {
    cidr_range = "10.0.0.0/16"
    az_list = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
    public_subnet_cidrs = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"]
    private_subnet_cidrs = ["10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19"]
}

task_scaling_config = {
    min = 1
    max = 10
    target_utilization = 100
}

compute_scaling_config = {
    min = 1
    max = 3
    target_utilization = 100
    instance_types = ["t3.medium", "t3a.medium"]
}

app_container_config = {
    container_port = 80
    cpu_requests = 256
    mem_requests = 512
}

# In practice, pipeline should be setting this value at deploy time after a container image build and deploy
image = "library/nginx:latest"
# Using upstream nginx image from dockerhub as an example
# In real use cases, this should be from ECR or a private repository deployed by a pipeline
# - avoid throttling from dockerhub
# - security (e.g. supply chain attacks, vuln scanning, etc)
# - build in and test app logic
# Additionally, for actual production use don't use mutable tags like `latest`

cert_config = {
    domain_name = "my.domain.com"
    hosted_zone_id = "ABCDEXAMPLE12345"
    route53_role = "arn:aws:iam::<ACCOUNT_ID>:role/Route53DeployRole"
}

deploy_role_arn = "arn:aws:iam::<DEPLOY_ACCOUNT_ID>:role/Terraform"