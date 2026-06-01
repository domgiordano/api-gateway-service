locals {
  origins_list = split(",", var.allow_origin)

  # CORS origin VTL. The Access-Control-Allow-Origin header is set ONLY here, via
  # $context.responseOverride — it must NOT also be mapped in the OPTIONS
  # integration response's response_parameters, or API Gateway returns a runtime
  # 500 ("Output mapping refused") whenever the override actually fires (i.e. for
  # any non-primary origin). Default to the primary origin, then echo whichever
  # configured origin matches the request. Always emitted (works for 1+ origins).
  cors_vtl = join("\n", concat(
    [
      "#set($origin = $input.params().header.get(\"Origin\"))",
      "#if($origin == \"\") #set($origin = $input.params().header.get(\"origin\")) #end",
      "#set($context.responseOverride.header.Access-Control-Allow-Origin = \"${local.origins_list[0]}\")",
    ],
    flatten([
      for o in local.origins_list : [
        "#if($origin == \"${o}\")",
        "  #set($context.responseOverride.header.Access-Control-Allow-Origin = $origin)",
        "#end",
      ]
    ]),
  ))

  default_access_log_format = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId $context.extendedRequestId"
  access_log_format         = var.access_log_format != "" ? var.access_log_format : local.default_access_log_format

  # Flatten all services into a single map keyed by "service/endpoint" for for_each.
  # `authorization` resolves to the per-endpoint override if set, else the module-level default.
  all_endpoints = merge([
    for svc_name, svc in var.services : {
      for ep in svc.endpoints : "${svc_name}/${ep.name}" => {
        service_name  = svc_name
        path_prefix   = svc.path_prefix
        name          = ep.name
        path_part     = ep.path_part
        http_method   = ep.http_method
        invoke_arn    = ep.invoke_arn
        authorization = ep.authorization != null ? ep.authorization : var.authorization
      }
    }
  ]...)

  # True when the module-level default OR any per-endpoint override needs the
  # COGNITO_USER_POOLS authorizer. Drives count on aws_api_gateway_authorizer.cognito.
  needs_cognito_authorizer = var.authorization == "COGNITO_USER_POOLS" || anytrue([
    for ep in local.all_endpoints : ep.authorization == "COGNITO_USER_POOLS"
  ])
}
