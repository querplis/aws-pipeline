variable "appname" {}
variable "region" {}
variable "instance_type" {}
variable "ssh_key_name" {}
variable "enable_autoscaling_group" {
  default = true
}
variable "github_owner" {}
variable "github_repo" {}
variable "github_branch" {}
variable "github_oauth_token" {}
