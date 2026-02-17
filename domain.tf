#######################################
# Custom Domain (optional)
#######################################

resource "aws_api_gateway_domain_name" "domain" {
  count                    = var.domain_name != "" ? 1 : 0
  domain_name              = var.domain_name
  regional_certificate_arn = var.certificate_arn
  security_policy          = "TLS_1_2"

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = merge(var.tags, { "Name" = "apig-domain-name" })
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  count       = var.domain_name != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.domain[0].domain_name
  stage_name  = aws_api_gateway_stage.stage.stage_name
}
