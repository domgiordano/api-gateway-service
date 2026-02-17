locals {
  endpoints_map = { for ep in var.endpoints : ep.name => ep }
  origins_list  = split(",", var.allow_origin)

  cors_vtl = length(local.origins_list) > 1 ? join("\n", [
    "#set($origin = $input.params().header.get(\"Origin\"))",
    "#if($origin == \"\") #set($origin = $input.params().header.get(\"origin\")) #end",
    join("\n", [for origin in slice(local.origins_list, 1, length(local.origins_list)) : "#if($origin.startsWith(\"${origin}\"))"]),
    "  #set($context.responseOverride.header.Access-Control-Allow-Origin = $origin)",
    "#end"
  ]) : ""
}
