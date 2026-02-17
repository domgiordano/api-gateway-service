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
