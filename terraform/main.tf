provider aws {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}


module "network" {
  source  = "./modules/network"
  region  = var.region
  appname = var.appname

}

module "lb" {
  source  = "./modules/lb"
  vpc     = "${module.network.vpc}"
  appname = var.appname

}

module "autoscaling" {
  source              = "./modules/autoscaling"
  appname             = var.appname
  vpc                 = "${module.network.vpc}"
  instance_type       = var.instance_type
  ssh_key_name        = var.ssh_key_name
  ssh_key_path        = var.ssh_key_path
  codepipeline_bucket = "${module.pipeline.codepipeline_bucket}"
}

module "pipeline" {
  source  = "./modules/pipeline"
  appname = var.appname
  vpc     = "${module.network.vpc}"

  autoscaling_group = "${module.autoscaling.autoscaling_group}"
  lb_target_group   = module.lb.lb_target_group

  # github
  github_owner       = var.github_owner
  github_repo        = var.github_repo
  github_branch      = var.github_branch
  github_oauth_token = var.github_oauth_token
}
