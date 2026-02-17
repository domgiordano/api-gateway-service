#######################################
# REST API
#######################################

resource "aws_api_gateway_rest_api" "api" {
  name                     = "${var.app_name}-api"
  description              = "API Gateway for ${var.app_name}"
  binary_media_types       = var.binary_media_types
  minimum_compression_size = var.minimum_compression_size
  tags                     = merge(var.tags, { "name" = "${var.app_name}-api-gateway" })

  endpoint_configuration {
    types = [var.endpoint_type]
  }
}

#######################################
# Stage and Deployment
#######################################

resource "aws_api_gateway_stage" "stage" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  tags          = merge(var.tags, { "name" = var.stage_name })

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = local.access_log_format
  }
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  description = "Deployed at ${timestamp()}"

  variables = {
    integrations = "Deployed at: ${timestamp()}"
  }

  triggers = {
    redeployment = sha1(jsonencode([timestamp()]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.endpoint,
    aws_api_gateway_integration.endpoint,
    aws_api_gateway_method.options,
    aws_api_gateway_integration.options,
  ]
}

#######################################
# Method Settings (logging/throttling)
#######################################

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = var.metrics_enabled
    data_trace_enabled     = var.data_trace_enabled
    logging_level          = var.logging_level
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }
}
