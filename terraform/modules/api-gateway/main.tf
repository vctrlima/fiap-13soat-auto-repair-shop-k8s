# =============================================================================
# API Gateway Module - HTTP API with Lambda + ALB integrations
# Routes:
#   POST /api/auth/cpf → Lambda (CPF-based auth, public)
#   ANY  /api/{proxy+} → ALB (protected by JWT authorizer)
#   GET  /health       → ALB (public)
#   GET  /docs/*       → ALB (public)
# =============================================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.resource_suffix}"
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.project_name}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-Request-ID"]
    max_age       = 3600
  }

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

# --- VPC Link to ALB ---
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link-${var.resource_suffix}"
  security_group_ids = [var.alb_security_group_id]
  subnet_ids         = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-vpc-link"
  }
}

# --- Lambda Authorizer (verifies custom HS256 JWTs) ---

data "archive_file" "authorizer" {
  type        = "zip"
  source_file = "${path.module}/authorizer/index.js"
  output_path = "${path.module}/authorizer/authorizer.zip"
}

resource "aws_iam_role" "authorizer" {
  name = "${var.project_name}-authorizer-${var.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "authorizer_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.authorizer.name
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${var.project_name}-authorizer-${var.resource_suffix}"
  retention_in_days = 30
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.project_name}-authorizer-${var.resource_suffix}"
  description      = "JWT authorizer for ${var.project_name} API Gateway"
  role             = aws_iam_role.authorizer.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256

  environment {
    variables = {
      JWT_ACCESS_TOKEN_SECRET = var.jwt_access_token_secret
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.authorizer.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.authorizer_basic,
    aws_cloudwatch_log_group.authorizer,
  ]
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.main.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${var.project_name}-jwt-authorizer"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 300
}

# --- Lambda Integration (CPF Auth) ---
resource "aws_apigatewayv2_integration" "lambda_auth" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# --- ALB Integration (Main App) ---
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = var.alb_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

# --- Grafana ALB Listener Rule ---
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = var.alb_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = var.grafana_target_group_arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }
}

# --- Routes ---

# Public: CPF Authentication (Lambda)
resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_auth.id}"
}

# Public: Health check (ALB)
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Public: Swagger docs (ALB)
resource "aws_apigatewayv2_route" "docs" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /docs/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Public: Admin auth (email+password, forwarded to app)
resource "aws_apigatewayv2_route" "auth_admin" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/auth"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Public: Refresh token
resource "aws_apigatewayv2_route" "auth_refresh" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /api/auth/refresh"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Public: Grafana dashboard
resource "aws_apigatewayv2_route" "grafana" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /grafana/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_route" "grafana_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /grafana"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Protected: All other API routes (require JWT)
resource "aws_apigatewayv2_route" "api_protected" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# --- Stage ---
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = {
    Name = "${var.project_name}-api-stage-${var.environment}"
  }
}

# --- CloudWatch Logs ---
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.resource_suffix}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

# --- Lambda Permission for API Gateway ---
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
