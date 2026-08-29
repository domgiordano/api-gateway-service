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
  description = "Managed by Terraform"

  # A deployment is a snapshot of the API, so it must be replaced exactly when
  # the API it would snapshot changes, and not otherwise.
  #
  # This hashed `timestamp()` until v2.8.0. That is evaluated at plan time and
  # always differs, so every plan in every consuming repo proposed a
  # replacement whether or not anything had changed. The cost was never the
  # redeploy — it was that no plan was ever clean, so genuine drift had nowhere
  # to show. Six tables in one consumer sat with deletion protection merged and
  # unapplied for weeks underneath exactly that noise.
  #
  # Everything a deployment captures is listed below, and the list has to stay
  # complete. A missing entry is the dangerous failure here: a real API change
  # would stop triggering a redeploy and nothing would say so, which is worse
  # than the noise this replaces. Add to it when adding a resource that shapes
  # the API surface.
  #
  # Stage-level things are deliberately absent — the stage, its method settings,
  # the domain and its base path mapping all apply without a deployment.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api,
      aws_api_gateway_resource.service,
      aws_api_gateway_resource.endpoint,
      aws_api_gateway_method.endpoint,
      aws_api_gateway_integration.endpoint,
      aws_api_gateway_method.options,
      aws_api_gateway_integration.options,
      aws_api_gateway_method_response.options,
      aws_api_gateway_integration_response.options,
      aws_api_gateway_authorizer.authorizer,
      aws_api_gateway_authorizer.cognito,
      aws_api_gateway_gateway_response.response_4xx,
      aws_api_gateway_gateway_response.response_5xx,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  # `depends_on` is gone because the triggers above reference every resource it
  # named, and more, so Terraform already orders this after all of them.
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
