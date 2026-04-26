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
  authorization = each.value.authorization
  authorizer_id = each.value.authorization == "CUSTOM" ? aws_api_gateway_authorizer.authorizer[0].id : null
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
# Lambda permissions
#######################################

resource "aws_lambda_permission" "invoke" {
  for_each      = local.all_endpoints
  statement_id  = "Allow${replace(title(each.value.path_prefix), "-", "")}${title(each.value.name)}Api"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^/]+)", each.value.invoke_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
