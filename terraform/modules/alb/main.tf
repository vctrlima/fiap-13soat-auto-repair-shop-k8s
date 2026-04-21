# =============================================================================
# ALB Module - Application Load Balancer, Target Group, Listener
# =============================================================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_to_eks_nodes" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3004
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.eks_nodes_security_group_id
  description              = "Allow ALB to reach application pods (ports 3001-3004)"
}

resource "aws_security_group_rule" "alb_to_eks_cluster_sg" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3004
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.eks_cluster_security_group_id
  description              = "Allow ALB to reach application pods via cluster SG (ports 3001-3004)"
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "production"

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# --- Per-service Target Groups ---

resource "aws_lb_target_group" "customer_vehicle" {
  name        = "ars-cv-${var.resource_suffix}"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-customer-vehicle-tg-${var.resource_suffix}"
  }
}

resource "aws_lb_target_group" "work_order" {
  name        = "ars-wo-${var.resource_suffix}"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-work-order-tg-${var.resource_suffix}"
  }
}

resource "aws_lb_target_group" "billing" {
  name        = "ars-bill-${var.resource_suffix}"
  port        = 3003
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-billing-tg-${var.resource_suffix}"
  }
}

resource "aws_lb_target_group" "execution" {
  name        = "ars-exec-${var.resource_suffix}"
  port        = 3004
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-execution-tg-${var.resource_suffix}"
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "ars-grafana-${var.resource_suffix}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/grafana/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-grafana-tg-${var.resource_suffix}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.acm_certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.acm_certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.acm_certificate_arn == "" ? aws_lb_target_group.customer_vehicle.arn : null
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.customer_vehicle.arn
  }

  tags = {
    Name = "${var.project_name}-https-listener"
  }
}

# --- Path-Based Listener Rules (priority 20-50; grafana is 10 in api-gateway module) ---

resource "aws_lb_listener_rule" "customer_vehicle" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.customer_vehicle.arn
  }

  condition {
    path_pattern {
      values = ["/api/customers*", "/api/vehicles*", "/internal/customers*"]
    }
  }
}

resource "aws_lb_listener_rule" "work_order" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.work_order.arn
  }

  condition {
    path_pattern {
      values = ["/api/work-orders*", "/api/services*", "/api/parts-or-supplies*", "/api/sagas*"]
    }
  }
}

resource "aws_lb_listener_rule" "billing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.billing.arn
  }

  condition {
    path_pattern {
      values = ["/api/invoices*", "/api/payments*"]
    }
  }
}

resource "aws_lb_listener_rule" "execution" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.execution.arn
  }

  condition {
    path_pattern {
      values = ["/api/executions*", "/api/notifications*", "/api/metrics*"]
    }
  }
}
