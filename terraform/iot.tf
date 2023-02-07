resource "aws_iot_thing_group" "this" {
  name = "${local.device_name}-group"
}

resource "aws_iot_thing" "this" {
  name = local.device_name
}

resource "aws_iot_thing_group_membership" "this" {
  thing_group_name = aws_iot_thing_group.this.name
  thing_name       = aws_iot_thing.this.name
}

resource "aws_iot_certificate" "this" {
  active = true
}

resource "aws_iot_thing_principal_attachment" "this" {
  principal = aws_iot_certificate.this.arn
  thing     = aws_iot_thing.this.name
}

resource "aws_iot_policy" "greengrass" {
  name = "${local.device_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iot:Publish",
          "iot:Subscribe",
          "iot:Receive",
          "iot:Connect",
          "greengrass:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iot_policy_attachment" "greengrass" {
  policy = aws_iot_policy.greengrass.name
  target = aws_iot_certificate.this.arn
}

resource "aws_iam_role" "token_exchange_role" {
  name = "${local.device_name}-service-role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "credentials.iot.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy" "token_exchange_role" {
  role = aws_iam_role.token_exchange_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*"
        ]
        Resource = [
          "${data.aws_s3_bucket.artifact.arn}",
          "${data.aws_s3_bucket.artifact.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = "arn:aws:iot:*:${data.aws_caller_identity.this.id}:topic/${var.target_iot_topic}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iot_role_alias" "this" {
  alias    = "${local.device_name}-role-alias"
  role_arn = aws_iam_role.token_exchange_role.arn
}

resource "aws_iot_policy" "attach" {
  name = "${local.device_name}-iot-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iot:AssumeRoleWithCertificate",
        ]
        Effect   = "Allow"
        Resource = aws_iot_role_alias.this.arn
      },
    ]
  })
}

resource "aws_iot_policy_attachment" "attach" {
  policy = aws_iot_policy.attach.name
  target = aws_iot_certificate.this.arn
}

resource "local_file" "device_cert" {
  content         = aws_iot_certificate.this.certificate_pem
  filename        = "${local.output_dir}/certs/device.pem.crt"
  file_permission = local.output_file_permission
}

resource "local_file" "private_key" {
  content         = aws_iot_certificate.this.private_key
  filename        = "${local.output_dir}/certs/private.pem.key"
  file_permission = local.output_file_permission
}

resource "local_file" "amazon_root_ca_pem" {
  content         = data.http.amazon_root_ca_pem.response_body
  filename        = "${local.output_dir}/certs/AmazonRootCA1.pem"
  file_permission = local.output_file_permission
}

resource "local_file" "config" {
  filename        = "${local.output_dir}/config/config.yaml"
  file_permission = local.output_file_permission
  content         = <<EOF
---
system:
  certificateFilePath: "/greengrass/certs/device.pem.crt"
  privateKeyPath: "/greengrass/certs/private.pem.key"
  rootCaPath: "/greengrass/certs/AmazonRootCA1.pem"
  rootpath: "/greengrass/v2"
  thingName: "${var.device_name}"
services:
  aws.greengrass.Nucleus:
    componentType: "NUCLEUS"
    version: "${var.greengrass_version}"
    configuration:
      awsRegion: "${var.region}"
      iotRoleAlias: "${aws_iot_role_alias.this.alias}"
      iotDataEndpoint: "${data.aws_iot_endpoint.data_ats.endpoint_address}"
      iotCredEndpoint: "${data.aws_iot_endpoint.credential_provider.endpoint_address}"
  aws.greengrass.Cli:
    componentVersion: "${var.greengrass_version}"
EOF
}
