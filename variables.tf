variable "rest_api_id" {
  description = "The ID of the REST API Gateway"
  type        = string
}

variable "root_resource_id" {
  description = "The root resource ID of the REST API Gateway"
  type        = string
}

variable "path_prefix" {
  description = "The top-level path for this service (e.g., 'user', 'friends')"
  type        = string
}

variable "endpoints" {
  description = "List of endpoint definitions for this service"
  type = list(object({
    name        = string
    path_part   = string
    http_method = string
    invoke_arn  = string
  }))
}

variable "authorization" {
  description = "Authorization type for methods. NONE, CUSTOM, AWS_IAM, COGNITO_USER_POOLS."
  type        = string
  default     = "CUSTOM"
}

variable "authorizer_id" {
  description = "The authorizer ID to use when authorization is CUSTOM or COGNITO_USER_POOLS"
  type        = string
  default     = ""
}

variable "execution_arn" {
  description = "The execution ARN of the REST API Gateway (for lambda permissions)"
  type        = string
}

variable "allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["Authorization", "Content-Type", "X-Amz-Date", "X-Amz-Security-Token", "X-Api-Key"]
}

variable "allow_origin" {
  description = "Comma-delimited string of allowed origins for CORS. Defaults to '*'"
  type        = string
  default     = "*"
}
