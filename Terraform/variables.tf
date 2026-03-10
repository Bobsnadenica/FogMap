variable "project_name" {
  type    = string
  default = "world-of-fog"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "allowed_upload_content_types" {
  type    = list(string)
  default = ["image/jpeg", "image/png", "image/webp"]
}

variable "max_landmark_upload_bytes" {
  type    = number
  default = 5242880
}

variable "max_pending_landmarks_per_user" {
  type    = number
  default = 10
}

variable "max_landmark_uploads_per_day" {
  type    = number
  default = 20
}

variable "presence_ttl_seconds" {
  type    = number
  default = 300
}

variable "presigned_upload_expiration_seconds" {
  type    = number
  default = 600
}

variable "cognito_admin_group_name" {
  type    = string
  default = "admin"
}

variable "cognito_moderator_group_name" {
  type    = string
  default = "moderator"
}

variable "cognito_user_group_name" {
  type    = string
  default = "user"
}

variable "cognito_callback_urls" {
  type    = list(string)
  default = []
}

variable "cognito_logout_urls" {
  type    = list(string)
  default = []
}

variable "cors_allowed_origins" {
  type    = list(string)
  default = ["*"]
}