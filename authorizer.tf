#######################################
# Authorizer
#######################################

resource "aws_api_gateway_authorizer" "authorizer" {
  count                            = var.authorization == "CUSTOM" ? 1 : 0
  name                             = "${var.app_name}-Api-Gateway-Lambda-Authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.api.id
  authorizer_uri                   = var.authorizer_invoke_arn
  authorizer_credentials           = var.authorizer_role_arn
  type                             = var.authorizer_type
  identity_source                  = var.authorizer_identity_source
  authorizer_result_ttl_in_seconds = var.authorizer_result_ttl_in_seconds
}

resource "aws_lambda_permission" "authorizer" {
  count         = var.authorization == "CUSTOM" ? 1 : 0
  statement_id  = "AllowExecFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^/]+)", var.authorizer_invoke_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*"
}
