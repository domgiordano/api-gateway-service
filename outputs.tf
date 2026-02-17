output "rest_api_id" {
  description = "The ID of the REST API"
  value       = aws_api_gateway_rest_api.api.id
}

output "rest_api_execution_arn" {
  description = "The execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "rest_api_root_resource_id" {
  description = "The root resource ID of the REST API"
  value       = aws_api_gateway_rest_api.api.root_resource_id
}

output "stage_name" {
  description = "The deployed stage name"
  value       = aws_api_gateway_stage.stage.stage_name
}

output "stage_invoke_url" {
  description = "The invoke URL of the deployed stage"
  value       = aws_api_gateway_stage.stage.invoke_url
}

output "stage_arn" {
  description = "The ARN of the deployed stage (for WAF associations, etc.)"
  value       = aws_api_gateway_stage.stage.arn
}

output "domain_regional_domain_name" {
  description = "Regional domain name of the custom domain (for Route53 alias)"
  value       = var.domain_name != "" ? aws_api_gateway_domain_name.domain[0].regional_domain_name : ""
}

output "domain_regional_zone_id" {
  description = "Regional hosted zone ID of the custom domain (for Route53 alias)"
  value       = var.domain_name != "" ? aws_api_gateway_domain_name.domain[0].regional_zone_id : ""
}

output "authorizer_id" {
  description = "The ID of the API Gateway authorizer (empty if no CUSTOM auth)"
  value       = var.authorization == "CUSTOM" ? aws_api_gateway_authorizer.authorizer[0].id : ""
}

output "service_resource_ids" {
  description = "Map of service name to parent API Gateway resource ID"
  value       = { for k, v in aws_api_gateway_resource.service : k => v.id }
}

output "endpoint_resource_ids" {
  description = "Map of 'service/endpoint' to API Gateway resource ID"
  value       = { for k, v in aws_api_gateway_resource.endpoint : k => v.id }
}
