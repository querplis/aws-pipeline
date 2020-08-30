resource "aws_security_group" "ltmpl_security_group" {
  name   = "${var.appname}-launch_template_security_group"
  vpc_id = var.vpc.id

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.appname}-allow"
  }
  depends_on = [
    var.vpc
  ]
}

data "aws_ami" "debian-10-amd64" {
  # find ami by name/owner
  name_regex = "^debian-10-amd64-20200803-347$"
  owners     = ["136693071363"]
}


resource "aws_iam_role" "launch_template_role" {
  name = "${var.appname}-launch_template_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "launch_template_profile" {
  name = "${var.appname}-launch_template_profile"
  role = aws_iam_role.launch_template_role.name
}


resource "aws_iam_role_policy" "launch_template_policy" {
  role = aws_iam_role.launch_template_role.id
  name = "${var.appname}-launch_template_policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "${var.codepipeline_bucket.arn}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_launch_template" "launch_template" {
  name          = var.appname
  user_data     = filebase64("${path.root}/provision.sh")
  instance_type = var.instance_type

  ebs_optimized = false
  iam_instance_profile {
    //name = aws_iam_role.launch_template_role.arn
    arn = aws_iam_instance_profile.launch_template_profile.arn
  }
  #subnet_id = aws_vpc.vpc.id
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.ltmpl_security_group.id]
  image_id               = data.aws_ami.debian-10-amd64.id
  key_name               = var.ssh_key_name
}


# get availablity zones
data "aws_availability_zones" "available" {
  state = "available"
}

# get subnet ids
data "aws_subnet_ids" "vpc" {
  vpc_id = var.vpc.id
  depends_on = [
    var.vpc
  ]
}

# autoscaling group
resource "aws_autoscaling_group" "autoscaling_group" {
  desired_capacity    = 3  # initial capacaity/and parameter that is changed by autoscaling
  max_size            = 10 # max size
  min_size            = 3  # min siize
  vpc_zone_identifier = data.aws_subnet_ids.vpc.ids
  #launch template
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
}

# scaling up policy
resource "aws_autoscaling_policy" "upscale_policy" {
  name = "${var.appname}-upscale-polcy"
  # nstance count we are adding
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

# scaling up allarm 
resource "aws_cloudwatch_metric_alarm" "upscale_alarm" {
  alarm_name          = "${var.appname}-upscale-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  # evaluation period count
  evaluation_periods = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  # evaluation period 60s
  period    = "60"
  statistic = "Average"
  # cpu utilization threshold
  threshold = "80"

  # autoscaling group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  # what to do when alarm triggers
  alarm_actions = [aws_autoscaling_policy.upscale_policy.arn]
}

# scaling down policy
resource "aws_autoscaling_policy" "downscale_policy" {
  name = "${var.appname}-downscale-polcy"
  # instace count we are removing
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

#scaling down alarm
resource "aws_cloudwatch_metric_alarm" "downscale_alarm" {
  alarm_name          = "${var.appname}-downscale-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  # evaluation period count
  evaluation_periods = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  # evaliuation period 60s
  period    = "60"
  statistic = "Average"
  threshold = "60"

  # autoscaling group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  # policy/whaat to do when aalarm triggers
  alarm_actions = [aws_autoscaling_policy.downscale_policy.arn]
}
