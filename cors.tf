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
