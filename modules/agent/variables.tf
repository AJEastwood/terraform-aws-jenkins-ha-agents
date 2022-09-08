
variable "agent_lt_version" {
  description = "The version of the agent launch template to use. Only use if you need to programatically select an older version of the launch template. Not recommended to change."
  type        = string
  default     = "$Latest"
}

variable "agent_max" {
  description = "The maximum number of agents to run in the agent ASG."
  type        = number
  default     = 6
}

variable "agent_min" {
  description = "The minimum number of agents to run in the agent ASG."
  type        = number
  default     = 2
}

variable "agent_volume_size" {
  description = "The size of the agent volume."
  type        = number
  default     = 16
}

variable "api_ssm_parameter" {
  description = "The path value of the API key, stored in ssm parameter store."
  type        = string
  default     = "/api_key"
}

variable "application" {
  description = "The application name, to be interpolated into many resources and tags. Unique to this project."
  type        = string
  default     = "jenkins"
}


variable "executors" {
  description = "The number of executors to assign to each agent. Must be an even number, divisible by two."
  type        = number
  default     = 4
}

variable "extra_agent_userdata" {
  description = "Extra agent user-data to add to the default built-in."
  type        = string
  default     = ""
}

variable "extra_agent_userdata_merge" {
  description = "Control how cloud-init merges extra agent user-data sections."
  type        = string
  default     = "list(append)+dict(recurse_array)+str()"
}

variable "instance_type" {
  description = "The type of instances to use for both ASG's. The first value in the list will be set as the master instance."
  type        = list(string)
  default     = ["t3a.xlarge", "t3.xlarge", "t2.xlarge"]
}


variable "key_name" {
  description = "SSH Key to launch instances."
  type        = string
  default     = null
}

variable "region" {
  description = "The AWS region to deploy the infrastructure too."
  type        = string
}

variable "aws_master_region" {
  description = "The AWS region Where the Master Node is belonged to."
  type        = string
  default     = "eu-west-1"
}

variable "retention_in_days" {
  description = "How many days to retain cloudwatch logs."
  type        = number
  default     = 90
}

variable "scale_down_number" {
  description = "Number of agents to destroy when scaling down."
  type        = number
  default     = -1
}

variable "scale_up_number" {
  description = "Number of agents to create when scaling up."
  type        = number
  default     = 1
}

variable "ssm_parameter" {
  description = "The full ssm parameter path that will house the api key and master admin password. Also used to grant IAM access to this resource."
  type        = string
}

variable "swarm_version" {
  description = "The version of swarm plugin to install on the agents. Update by updating this value."
  type        = string
  default     = "3.32"
}

variable "tags" {
  description = "tags to define locally, and interpolate into the tags in this module."
  type        = map(string)
}

variable "jenkins_username" {
  description = "Special username to connect the agents. Useful when you want to use Azure AD authentication, then you need to pass an username that exisits in the AD, otherwise agents wont be able to connect to amster when you switch over to Azure AD auth with configuration as code plugin"
  type = string
}

variable "enable_spot_insances" {
  description = "1 if it is enabled, 0 to disable spot insance pools. Useful to disable if jenkins used to deploy infrastructure resources with terraform preventing broken terraform state when spot instance removed from the agent pool"
  type = number
  default = 1
}

variable "bastion_sg_name" {
  description = "The bastion security group name to allow to ssh to the master/agents."
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC the infrastructure will be deployed to."
  type        = string
}

variable "ami_name" {
  description = "The name of the amzn2 ami. Used for searching for AMI id."
  type        = string
  default     = "amzn2-ami-hvm-2.0.*-x86_64-gp2"
}

variable "ami_owner" {
  description = "The owner of the amzn2 ami."
  type        = string
  default     = "amazon"
}

variable "private_subnet_name" {
  description = "The name prefix of the private subnets to pull in as a data source."
  type        = string
}
