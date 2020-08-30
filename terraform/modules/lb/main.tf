# get subnet ids
data "aws_subnet_ids" "vpc" {
  vpc_id = var.vpc.id
  depends_on = [ 
    var.vpc 
  ]
}

# security group for aws
resource "aws_security_group" "lb_security_group" {
  name   = "${var.appname}-lb_security_group"
  vpc_id = var.vpc.id

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.appname}-lb-allow-http-sg"
  }
}

#load balancer
resource "aws_lb" "lb" {
  name               = "${var.appname}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_security_group.id]
  subnets            = data.aws_subnet_ids.vpc.ids

  tags =  {
    Name = "${var.appname}-lb"
  }
}

# load balancer target group
resource "aws_lb_target_group" "lb_target_group" {
  name = "${var.appname}-tg"

  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc.id

  health_check {
    path = "/"
    port = 80
  }
}

#load balancer listener

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
