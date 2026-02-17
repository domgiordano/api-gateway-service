############################
# Core
############################

variable "app_name" {
  description = "Application name, used for naming resources"
  type        = string
}

variable "stage_name" {
  description = "API Gateway stage name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

############################
# Services / Endpoints
############################

variable "services" {
  description = "Map of API services. Each service creates a parent path with child endpoints."
  type = map(object({
    path_prefix = string
    endpoints = list(object({
      name        = string
      path_part   = string
      http_method = string
      invoke_arn  = string
    }))
  }))
}

############################
# Authorization
############################

variable "authorization" {
  description = "Authorization type for methods. NONE, CUSTOM, AWS_IAM, COGNITO_USER_POOLS."
  type        = string
  default     = "CUSTOM"
}

variable "authorizer_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  type        = string
  default     = ""
}

variable "authorizer_role_arn" {
  description = "IAM role ARN for the authorizer to invoke the Lambda"
  type        = string
  default     = ""
}

############################
# Custom Domain (optional)
############################

variable "domain_name" {
  description = "Custom domain name for the API (e.g., api.myapp.com). Leave empty to skip."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the custom domain. Required if domain_name is set."
  type        = string
  default     = ""
}

############################
# REST API Configuration
############################

variable "endpoint_type" {
  description = "API Gateway endpoint type. REGIONAL or EDGE."
  type        = string
  default     = "REGIONAL"
}

variable "binary_media_types" {
  description = "List of binary media types supported by the REST API"
  type        = list(string)
  default     = ["multipart/form-data"]
}

variable "minimum_compression_size" {
  description = "Minimum response size (bytes) to compress. -1 to disable."
  type        = number
  default     = 5242880
}

############################
# Logging / Throttling
############################

variable "logging_level" {
  description = "CloudWatch logging level for API Gateway. OFF, ERROR, or INFO."
  type        = string
  default     = "INFO"
}

variable "metrics_enabled" {
  description = "Enable CloudWatch metrics for API Gateway"
  type        = bool
  default     = true
}

variable "data_trace_enabled" {
  description = "Enable full request/response data logging"
  type        = bool
  default     = true
}

variable "throttling_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

variable "access_log_format" {
  description = "Access log format for the API Gateway stage. Set to empty string to use default format."
  type        = string
  default     = ""
}

############################
# CORS
############################

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
