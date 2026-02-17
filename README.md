# api-gateway-service

Reusable Terraform module that creates a complete AWS API Gateway REST API stack with Lambda (AWS_PROXY) integration, CORS, authorization, custom domain, logging, and throttling.

## What it creates

- REST API Gateway with configurable endpoint type
- Lambda authorizer (when using CUSTOM auth)
- CloudWatch log group for access logs
- Stage and auto-deploying deployment
- Method settings (logging, metrics, throttling)
- Gateway responses for 4XX/5XX with CORS headers
- Custom domain name and base path mapping (optional)
- Per-service parent resources with child endpoints
- OPTIONS preflight handlers with CORS on every endpoint
- Lambda invoke permissions for all endpoints

## Usage

```hcl
module "api" {
  source = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v2.1.0"

  app_name              = "myapp"
  stage_name            = "dev"
  authorizer_invoke_arn = aws_lambda_function.authorizer.invoke_arn
  authorizer_role_arn   = aws_iam_role.lambda_role.arn
  tags                  = { source = "terraform", app_name = "myapp" }

  # Custom domain (optional)
  domain_name     = "myapp.com"
  certificate_arn = aws_acm_certificate.cert.arn

  services = {
    user = {
      path_prefix = "user"
      endpoints = [
        {
          name        = "update"
          path_part   = "update"
          http_method = "POST"
          invoke_arn  = aws_lambda_function.user["update"].invoke_arn
        },
        {
          name        = "all"
          path_part   = "all"
          http_method = "GET"
          invoke_arn  = aws_lambda_function.user["all"].invoke_arn
        },
      ]
    }
    friends = {
      path_prefix = "friends"
      endpoints = [
        for l in local.friends_lambdas : {
          name        = l.name
          path_part   = l.path_part
          http_method = l.http_method
          invoke_arn  = aws_lambda_function.friends[l.name].invoke_arn
        }
      ]
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `app_name` | Application name for resource naming | `string` | — | yes |
| `services` | Map of services with endpoints (see below) | `map(object)` | — | yes |
| `stage_name` | Stage name (e.g., dev, prod) | `string` | `"dev"` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |
| `authorization` | Auth type: `NONE`, `CUSTOM`, `AWS_IAM`, `COGNITO_USER_POOLS` | `string` | `"CUSTOM"` | no |
| `authorizer_invoke_arn` | Lambda authorizer invoke ARN (required when auth=CUSTOM) | `string` | `""` | no |
| `authorizer_role_arn` | IAM role ARN for authorizer (required when auth=CUSTOM) | `string` | `""` | no |
| `domain_name` | Custom domain name for the API. Leave empty to skip. | `string` | `""` | no |
| `certificate_arn` | ACM certificate ARN for the custom domain. Required if domain_name is set. | `string` | `""` | no |
| `endpoint_type` | API endpoint type: `REGIONAL` or `EDGE` | `string` | `"REGIONAL"` | no |
| `binary_media_types` | Binary media types for the REST API | `list(string)` | `["multipart/form-data"]` | no |
| `minimum_compression_size` | Min response size (bytes) to compress | `number` | `5242880` | no |
| `logging_level` | CloudWatch logging: `OFF`, `ERROR`, `INFO` | `string` | `"INFO"` | no |
| `metrics_enabled` | Enable CloudWatch metrics | `bool` | `true` | no |
| `data_trace_enabled` | Enable full request/response logging | `bool` | `true` | no |
| `throttling_rate_limit` | Requests per second limit | `number` | `100` | no |
| `throttling_burst_limit` | Burst request limit | `number` | `50` | no |
| `log_retention_days` | Log group retention in days | `number` | `14` | no |
| `access_log_format` | Custom access log format (empty for default) | `string` | `""` | no |
| `allow_headers` | CORS allowed headers | `list(string)` | `["Authorization", "Content-Type", ...]` | no |
| `allow_origin` | CORS origin(s), comma-delimited for multiple | `string` | `"*"` | no |

### Service and endpoint shape

```hcl
services = {
  service_name = {
    path_prefix = string   # URL path (e.g., "user", "friends")
    endpoints = [
      {
        name        = string  # Unique ID within the service
        path_part   = string  # URL segment (e.g., "update")
        http_method = string  # GET, POST, PUT, DELETE
        invoke_arn  = string  # Lambda invoke ARN
      }
    ]
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| `rest_api_id` | REST API ID (for WAF, etc.) |
| `rest_api_execution_arn` | Execution ARN of the REST API |
| `rest_api_root_resource_id` | Root resource ID |
| `stage_name` | Deployed stage name |
| `stage_invoke_url` | Stage invoke URL |
| `stage_arn` | Stage ARN (for WAF associations, etc.) |
| `domain_regional_domain_name` | Regional domain name of the custom domain (for Route53 alias) |
| `domain_regional_zone_id` | Regional hosted zone ID of the custom domain (for Route53 alias) |
| `authorizer_id` | Authorizer ID (empty if auth != CUSTOM) |
| `service_resource_ids` | Map of service name to parent resource ID |
| `endpoint_resource_ids` | Map of "service/endpoint" to resource ID |

## What stays outside the module

These are project-specific and should be defined in your project's Terraform:

- **Route53 DNS record** for the custom domain (use `domain_regional_domain_name` and `domain_regional_zone_id` outputs)
- **ACM certificate** and DNS validation records
- **WAF** association (`aws_wafv2_web_acl_association` using `stage_arn` output)
- **API Gateway account** CloudWatch role (`aws_api_gateway_account`) — account-level singleton
- **Authorizer Lambda function** — the Lambda itself with your custom auth code

## CORS

OPTIONS preflight handlers are automatically created for every endpoint with configurable headers and origins. For multi-origin CORS, pass a comma-delimited string to `allow_origin`. Gateway responses (4XX/5XX) also include CORS headers.

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS Provider | >= 4.0 |
