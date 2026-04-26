locals {
  origins_list = split(",", var.allow_origin)

  cors_vtl = length(local.origins_list) > 1 ? join("\n", [
    "#set($origin = $input.params().header.get(\"Origin\"))",
    "#if($origin == \"\") #set($origin = $input.params().header.get(\"origin\")) #end",
    join("\n", [for origin in slice(local.origins_list, 1, length(local.origins_list)) : "#if($origin.startsWith(\"${origin}\"))"]),
    "  #set($context.responseOverride.header.Access-Control-Allow-Origin = $origin)",
    "#end"
  ]) : ""

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
}
