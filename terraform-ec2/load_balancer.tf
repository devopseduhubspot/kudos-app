# ==============================================================================
# LOAD BALANCER CONFIGURATION
# ==============================================================================
# Creates Application Load Balancer for high availability and traffic distribution
# Demonstrates traditional load balancing vs container orchestration
# ==============================================================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = false
  
  # Access logs (optional - uncomment and provide S3 bucket)
  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   prefix  = "alb-logs"
  #   enabled = true
  # }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
    Type = "ApplicationLoadBalancer"
  })
}

# Target group for web servers
resource "aws_lb_target_group" "web_servers" {
  name     = "${local.name_prefix}-tg"
  port     = local.nginx_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  # Stickiness (session affinity)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = false   # Disable for stateless apps
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-target-group"
    Type = "TargetGroup"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Load balancer listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_servers.arn
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-listener"
    Type = "Listener"
  })
}

# Optional: HTTPS listener (uncomment if you have SSL certificate)
# resource "aws_lb_listener" "web_https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = aws_acm_certificate.main.arn
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.web_servers.arn
#   }
# }

# Optional: Route 53 record (uncomment if you have a domain)
# resource "aws_route53_record" "main" {
#   count   = var.domain_name != "" ? 1 : 0
#   zone_id = data.aws_route53_zone.main[0].zone_id
#   name    = var.domain_name
#   type    = "A"
# 
#   alias {
#     name                   = aws_lb.main.dns_name
#     zone_id                = aws_lb.main.zone_id
#     evaluate_target_health = true
#   }
# }