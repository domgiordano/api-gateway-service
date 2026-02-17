#######################################
# Parent resource (e.g., /user, /friends)
#######################################
resource "aws_api_gateway_resource" "parent" {
  rest_api_id = var.rest_api_id
  parent_id   = var.root_resource_id
  path_part   = var.path_prefix
}

#######################################
# Per-endpoint resources
#######################################

# Child resource path (e.g., /user/update)
resource "aws_api_gateway_resource" "endpoint" {
  for_each    = local.endpoints_map
  rest_api_id = var.rest_api_id
  parent_id   = aws_api_gateway_resource.parent.id
  path_part   = each.value.path_part
}

# Actual method (GET/POST/PUT/DELETE with authorization)
resource "aws_api_gateway_method" "endpoint" {
  for_each      = local.endpoints_map
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = each.value.http_method
  authorization = var.authorization
  authorizer_id = var.authorizer_id
}

# Lambda integration (AWS_PROXY)
resource "aws_api_gateway_integration" "endpoint" {
  for_each                = local.endpoints_map
  rest_api_id             = var.rest_api_id
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
  for_each      = local.endpoints_map
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each    = local.endpoints_map
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.endpoint[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }

  content_handling = "CONVERT_TO_TEXT"
}

resource "aws_api_gateway_method_response" "options" {
  for_each    = local.endpoints_map
  rest_api_id = var.rest_api_id
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
  for_each    = local.endpoints_map
  rest_api_id = var.rest_api_id
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
  for_each      = local.endpoints_map
  statement_id  = "Allow${replace(title(var.path_prefix), "-", "")}${title(each.key)}Api"
  action        = "lambda:InvokeFunction"
  function_name = split(":", each.value.invoke_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.execution_arn}/*/*"
}
