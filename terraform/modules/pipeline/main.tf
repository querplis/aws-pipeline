
#bucket for pipeline artifact store
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket_prefix = "${var.appname}-codepipeline-bucket"
  acl    = "private"
}


#role for pipeliine
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.appname}-pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# permissions for pipeline role
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:RegisterApplicationRevision"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

#pipeline
resource "aws_codepipeline" "codepipeline" {
  name     = "${var.appname}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

  }

  # get code from github 
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner                = var.github_owner
        Repo                 = var.github_repo
        Branch               = var.github_branch
        OAuthToken           = var.github_oauth_token
        PollForSourceChanges = false
      }
    }
  }

  # build code  ( buildspec.yml )
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = var.appname
        DeploymentGroupName = "${var.appname}-codedeploy_group"
      }
    }
  }
}





resource "aws_iam_role" "codedeploy_deployment_role" {
  name = "${var.appname}-codedeploy_deployment_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


#permissions for pipeline role
resource "aws_iam_role_policy" "code_deploy_policy" {
  name = "codedeploy_deployment"
  role = aws_iam_role.codedeploy_deployment_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole",
                "ec2:RunInstances",
                "ec2:CreateTags"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "codedeploya" {
  name       = "AWSCodeDeployRole"
  roles      = [aws_iam_role.codedeploy_deployment_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_iam_policy_attachment" "codedeployb" {
  name       = "AWSCodeDeployRole"
  roles      = [aws_iam_role.codedeploy_deployment_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = var.appname
}



resource "aws_codedeploy_deployment_group" "codedeploy_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.appname}-codedeploy_group"
  service_role_arn      =  aws_iam_role.codedeploy_deployment_role.arn
  //autoscaling_groups    = [aws_autoscaling_group.autoscaling_group.name]
  autoscaling_groups    = [var.autoscaling_group.name]


  # deployment config, this one is alreayd provided by aws
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  #rollback on deployment failure
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
    }

    # green fleet provisioning strategy
    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  # target group
  load_balancer_info {
    target_group_info {
      name = var.lb_target_group.name
    }
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }
  # attempt to fix issues with autoscaling groups name change 
  # lifecycle {
  #     ignore_changes = [autoscaling_groups]
  # }
}
