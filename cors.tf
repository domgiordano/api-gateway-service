#######################################
# CORS - OPTIONS preflight per endpoint
#######################################

resource "aws_api_gateway_method" "options" {
  for_each      = local.all_endpoints
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"

  # Origin has to be declared here before the integration below can map it in.
  # Not required (false): a request without Origin is not a preflight, and the
  # VTL already falls back to the primary origin.
  request_parameters = {
    "method.request.header.Origin" = false
  }
}

resource "aws_api_gateway_integration" "options" {
  for_each    = local.all_endpoints
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.endpoint[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  # Without this, $input.params().header is EMPTY in the response template
  # below. A MOCK integration receives only what is mapped into it -- its
  # request is the static template, not the caller's request -- so every
  # .get("Origin") returned null and the multi-origin echo could never match.
  request_parameters = {
    "integration.request.header.Origin" = "method.request.header.Origin"
  }

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
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
  # Access-Control-Allow-Origin is intentionally NOT mapped here — it is set
  # exclusively via $context.responseOverride in local.cors_vtl. Mapping it both
  # ways makes API Gateway 500 when the override fires (see locals.tf).

  response_templates = {
    "application/json" = local.cors_vtl
  }

  depends_on = [aws_api_gateway_method_response.options]
}
