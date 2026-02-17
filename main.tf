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
# Authorizer
#######################################

resource "aws_api_gateway_authorizer" "authorizer" {
  count                  = var.authorization == "CUSTOM" ? 1 : 0
  name                   = "${var.app_name}-Api-Gateway-Lambda-Authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = var.authorizer_invoke_arn
  authorizer_credentials = var.authorizer_role_arn
}

resource "aws_lambda_permission" "authorizer" {
  count         = var.authorization == "CUSTOM" ? 1 : 0
  statement_id  = "AllowExecFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.authorizer_invoke_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*"
}

#######################################
# CloudWatch Log Group
#######################################

resource "aws_cloudwatch_log_group" "api" {
  name              = "${var.app_name}-api-gateway-logs"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { "name" = "${var.app_name}-APIGW-Access-Logs" })
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

#######################################
# Gateway Responses (CORS on errors)
#######################################

resource "aws_api_gateway_gateway_response" "response_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  status_code   = "500"
  response_type = "DEFAULT_5XX"

  response_templates = {
    "application/json" = "{\"message\": \"$context.error.validationErrorString\"}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${local.origins_list[0]}'"
  }
}

resource "aws_api_gateway_gateway_response" "response_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  status_code   = "403"
  response_type = "DEFAULT_4XX"

  response_templates = {
    "application/json" = "{\"message\": \"$context.error.message\"}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${local.origins_list[0]}'"
  }
}

#######################################
# Service parent resources
#######################################

resource "aws_api_gateway_resource" "service" {
  for_each    = var.services
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.path_prefix
}

#######################################
# Per-endpoint resources
#######################################

resource "aws_api_gateway_resource" "endpoint" {
  for_each    = local.all_endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.service[each.value.service_name].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "endpoint" {
  for_each      = local.all_endpoints
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = each.value.http_method
  authorization = var.authorization
  authorizer_id = var.authorization == "CUSTOM" ? aws_api_gateway_authorizer.authorizer[0].id : null
}

resource "aws_api_gateway_integration" "endpoint" {
  for_each                = local.all_endpoints
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.endpoint[each.key].id
  http_method             = aws_api_gateway_method.endpoint[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
}

#######################################
# CORS - OPTIONS preflight per endpoint
#######################################

resource "aws_api_gateway_method" "options" {
  for_each      = local.all_endpoints
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each    = local.all_endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.endpoint[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }

  content_handling = "CONVERT_TO_TEXT"
}

resource "aws_api_gateway_method_response" "options" {
  for_each    = local.all_endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.endpoint[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each    = local.all_endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.endpoint[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'${join(",", var.allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods"     = "'${each.value.http_method},OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"      = "'${local.origins_list[0]}'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }

  response_templates = {
    "application/json" = local.cors_vtl
  }

  depends_on = [aws_api_gateway_method_response.options]
}

#######################################
# Lambda permissions
#######################################

resource "aws_lambda_permission" "invoke" {
  for_each      = local.all_endpoints
  statement_id  = "Allow${replace(title(each.value.path_prefix), "-", "")}${title(each.value.name)}Api"
  action        = "lambda:InvokeFunction"
  function_name = split(":", each.value.invoke_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
