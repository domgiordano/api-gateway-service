#######################################
# CloudWatch Log Group
#######################################

resource "aws_cloudwatch_log_group" "api" {
  name              = "${var.app_name}-api-gateway-logs"
  retention_in_days = var.log_retention_days
  tags              = merge(var.tags, { "name" = "${var.app_name}-APIGW-Access-Logs" })
}
