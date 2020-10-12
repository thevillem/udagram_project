
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.57.0"

  for_each = var.project

  name = each.key

  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.available.names
  private_subnets = slice(var.private_subnet_cidr_blocks, 0, each.value.private_subnet_count)
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, each.value.public_subnet_count)

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "3.16.0"

  for_each = var.project

  name        = "web-server-sg-${each.key}-${each.value.environment}"
  description = "Security group for web-servers with HTTP ports open within VPC"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress_cidr_blocks = module.vpc[each.key].public_subnets_cidr_blocks
}

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "3.16.0"

  for_each = var.project

  name = "load-balancer-sg-${each.key}-${each.value.environment}"

  description = "Security group for load balancer with HTTP ports open within VPC"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "random_string" "lb_id" {
  length  = 4
  special = false
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "2.4.0"

  for_each = var.project

  # Comply with ELB name restrictions 
  # https://docs.aws.amazon.com/elasticloadbalancing/2012-06-01/APIReference/API_CreateLoadBalancer.html
  name     = trimsuffix(substr(replace(join("-", ["lb", random_string.lb_id.result, each.key, each.value.environment]), "/[^a-zA-Z0-9-]/", ""), 0, 32), "-")
  internal = false

  security_groups = [module.lb_security_group[each.key].this_security_group_id]
  subnets         = module.vpc[each.key].public_subnets

  listener = [{
    instance_port     = "80"
    instance_protocol = "HTTP"
    lb_port           = "80"
    lb_protocol       = "HTTP"
  }]

  health_check = {
    target              = "HTTP:80/"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }
}

resource "aws_iam_role" "web_app_role" {
  name = "udagram-app_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach-s3_read" {
  role       = aws_iam_role.web_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "attach-cloudwatch" {
  role       = aws_iam_role.web_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_instance_profile" "web_asg_profile" {
  name = "udagram-instance_profile"
  role = aws_iam_role.web_app_role.name
}

resource "aws_launch_configuration" "auto_launch_config" {
  name = "udagram-lc"

  for_each = var.project

  image_id        = each.value.ami_id
  instance_type   = each.value.instance_type
  security_groups = [module.lb_security_group[each.key].this_security_group_id]

  iam_instance_profile = aws_iam_instance_profile.web_asg_profile.name

  user_data = file("init.sh")

  ebs_block_device {
    device_name           = "/dev/xvdz"
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  root_block_device {
    volume_size = "10"
    volume_type = "gp2"
  }

}

resource "aws_autoscaling_group" "auto_scaling_group" {
  name = "udagram_asg"

  for_each = var.project

  vpc_zone_identifier = module.vpc[each.key].private_subnets

  max_size             = 3
  min_size             = 1
  launch_configuration = aws_launch_configuration.auto_launch_config[each.key].id

}

resource "aws_autoscaling_attachment" "asg_attachment" {

  for_each = var.project

  autoscaling_group_name = aws_autoscaling_group.auto_scaling_group[each.key].id
  elb                    = module.elb_http[each.key].this_elb_id
}

resource "aws_autoscaling_policy" "scale_up" {
  for_each               = var.project
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.auto_scaling_group[each.key].name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each            = var.project
  alarm_name          = "cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.auto_scaling_group[each.key].name
  }

  alarm_description = "Scale up if CPU utilization is above 70% for 300 seconds"
  alarm_actions     = [aws_autoscaling_policy.scale_up[each.key].arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  for_each               = var.project
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.auto_scaling_group[each.key].name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  for_each            = var.project
  alarm_name          = "cpu-utilization-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 10

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.auto_scaling_group[each.key].name
  }

  alarm_description = "Scale down if the CPU utilization is below 10% for 300 seconds"
  alarm_actions     = [aws_autoscaling_policy.scale_down[each.key].arn]
}

output "elb_dns_name" {
  value = [
    for elb in module.elb_http :
    "http://${elb.this_elb_dns_name}"
  ]
}