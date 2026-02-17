# api-gateway-service

Reusable Terraform module for creating AWS API Gateway REST API service endpoints with Lambda (AWS_PROXY) integration and CORS support.

## What it creates

Per service invocation:
- 1 parent API Gateway resource (e.g., `/user`)
- Per endpoint: child resource, HTTP method, Lambda integration, OPTIONS preflight with CORS headers, and Lambda invoke permission

## Usage

```hcl
module "user_api" {
  source = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v1.0.0"

  rest_api_id      = aws_api_gateway_rest_api.api.id
  root_resource_id = aws_api_gateway_rest_api.api.root_resource_id
  path_prefix      = "user"
  authorizer_id    = aws_api_gateway_authorizer.auth.id
  execution_arn    = aws_api_gateway_rest_api.api.execution_arn

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
```

### Multiple services with `for_each`

```hcl
locals {
  api_services = {
    user = {
      path_prefix = "user"
      endpoints = [
        for l in local.user_lambdas : {
          name        = l.name
          path_part   = l.path_part
          http_method = l.http_method
          invoke_arn  = aws_lambda_function.user[l.name].invoke_arn
        }
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

module "api_services" {
  source   = "git::https://github.com/domgiordano/api-gateway-service.git?ref=v1.0.0"
  for_each = local.api_services

  rest_api_id      = aws_api_gateway_rest_api.api.id
  root_resource_id = aws_api_gateway_rest_api.api.root_resource_id
  path_prefix      = each.value.path_prefix
  endpoints        = each.value.endpoints
  authorizer_id    = aws_api_gateway_authorizer.auth.id
  execution_arn    = aws_api_gateway_rest_api.api.execution_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `rest_api_id` | The ID of the REST API Gateway | `string` | — | yes |
| `root_resource_id` | The root resource ID of the REST API Gateway | `string` | — | yes |
| `path_prefix` | Top-level path for this service (e.g., `user`, `friends`) | `string` | — | yes |
| `endpoints` | List of endpoint definitions (see below) | `list(object)` | — | yes |
| `execution_arn` | Execution ARN of the REST API (for Lambda permissions) | `string` | — | yes |
| `authorization` | Authorization type: `NONE`, `CUSTOM`, `AWS_IAM`, `COGNITO_USER_POOLS` | `string` | `"CUSTOM"` | no |
| `authorizer_id` | Authorizer ID for `CUSTOM` or `COGNITO_USER_POOLS` auth | `string` | `""` | no |
| `allow_headers` | CORS allowed headers | `list(string)` | `["Authorization", "Content-Type", ...]` | no |
| `allow_origin` | CORS allowed origin(s), comma-delimited for multiple | `string` | `"*"` | no |

### Endpoint object shape

```hcl
{
  name        = string  # Unique identifier for the endpoint
  path_part   = string  # URL path segment (e.g., "update", "all")
  http_method = string  # HTTP method (GET, POST, PUT, DELETE)
  invoke_arn  = string  # Lambda function invoke ARN
}
```

## Outputs

| Name | Description |
|------|-------------|
| `parent_resource_id` | Resource ID of the parent path |
| `endpoint_resource_ids` | Map of endpoint name to API Gateway resource ID |

## CORS

The module automatically creates OPTIONS preflight handlers for each endpoint with:
- `Access-Control-Allow-Headers` — configurable via `allow_headers`
- `Access-Control-Allow-Methods` — auto-set to the endpoint's HTTP method + OPTIONS
- `Access-Control-Allow-Origin` — configurable via `allow_origin`
- `Access-Control-Allow-Credentials` — always `true`

For multi-origin CORS, pass a comma-delimited string to `allow_origin` (e.g., `"https://app.example.com,https://staging.example.com"`). The module uses VTL response templates to dynamically match the request origin.

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS Provider | >= 4.0 |
