output "parent_resource_id" {
  description = "The resource ID of the parent path (e.g., /user)"
  value       = aws_api_gateway_resource.parent.id
}

output "endpoint_resource_ids" {
  description = "Map of endpoint name to API Gateway resource ID"
  value       = { for k, v in aws_api_gateway_resource.endpoint : k => v.id }
}
