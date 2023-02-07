locals {
  device_name            = var.device_name
  output_dir             = "${path.cwd}/${var.config_dir}"
  artifact_bucket        = var.bucket
  prefix                 = "${var.artifacts_dir}/${var.component_name}/${var.component_version}"
  artifact_dir           = "${path.cwd}/${local.prefix}"
  artifact_s3_key_prefix = local.prefix
  output_file_permission = "0666"
}

data "aws_caller_identity" "this" {}

data "aws_iot_endpoint" "data_ats" {
  endpoint_type = "iot:Data-ATS"
}

data "aws_iot_endpoint" "credential_provider" {
  endpoint_type = "iot:CredentialProvider"
}

data "http" "amazon_root_ca_pem" {
  url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
}

data "aws_s3_bucket" "artifact" {
  bucket = local.artifact_bucket
}
