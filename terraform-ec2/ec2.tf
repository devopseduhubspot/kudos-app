# ==============================================================================
# EC2 INSTANCES AND AUTO SCALING
# ==============================================================================
# Creates EC2 instances with auto scaling for high availability
# Demonstrates traditional server deployment vs containerization
# ==============================================================================

# Create key pair for SSH access (if not provided)
resource "aws_key_pair" "main" {
  count = var.key_pair_name == "" ? 1 : 0
  
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.main[0].public_key_openssh
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
    Type = "KeyPair"
  })
}

# Generate SSH key pair if not provided
resource "tls_private_key" "main" {
  count = var.key_pair_name == "" ? 1 : 0
  
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  count = var.key_pair_name == "" ? 1 : 0
  
  content         = tls_private_key.main[0].private_key_pem
  filename        = "${path.module}/${local.name_prefix}-key.pem"
  file_permission = "0600"
}

# ==============================================================================
# LAUNCH TEMPLATE
# ==============================================================================
resource "aws_launch_template" "web_server" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.main[0].key_name
  
  vpc_security_group_ids = [aws_security_group.web_servers.id]
  
  # User data script for basic setup
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name = var.app_name
    app_port = local.app_port
  }))
  
  # Instance metadata options
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 2
  }
  
  # Block device mapping
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web-server"
      Type = "WebServer"
      Role = "Application"
    })
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-web-server-volume"
      Type = "EBS"
    })
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-launch-template"
    Type = "LaunchTemplate"
  })
}

# ==============================================================================
# AUTO SCALING GROUP
# ==============================================================================
resource "aws_autoscaling_group" "web_servers" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web_servers.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_servers
  max_size         = var.max_servers
  desired_capacity = var.min_servers
  
  # Use latest version of launch template
  launch_template {
    id      = aws_launch_template.web_server.id
    version = "$Latest"
  }
  
  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  
  # Tags applied to instances
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-web-server"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Project"
    value               = var.app_name
    propagate_at_launch = true
  }
  
  tag {
    key                 = "AnsibleGroup"
    value               = "webservers"
    propagate_at_launch = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# AUTO SCALING POLICIES
# ==============================================================================
# Scale up policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${local.name_prefix}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_servers.name
}

# Scale down policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${local.name_prefix}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_servers.name
}

# CloudWatch alarms for auto scaling
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_servers.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_servers.name
  }
  
  tags = local.common_tags
}