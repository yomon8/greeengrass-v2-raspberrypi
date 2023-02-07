resource "aws_s3_object" "requirements_txt" {
  bucket = local.artifact_bucket
  key    = "${local.artifact_s3_key_prefix}/requirements.txt"
  source = "${local.artifact_dir}/requirements.txt"
}
resource "aws_s3_object" "main" {
  bucket = local.artifact_bucket
  key    = "${local.artifact_s3_key_prefix}/main.py"
  source = "${local.artifact_dir}/main.py"
}

resource "local_file" "component" {
  filename        = "${local.output_dir}/component/${var.component_name}_${var.component_version}.json"
  file_permission = local.output_file_permission
  content         = <<EOF
{
  "RecipeFormatVersion": "2020-01-25",
  "ComponentName": "${var.component_name}",
  "ComponentVersion": "${var.component_version}",
  "ComponentDescription": "A component that publishes messages.",
  "ComponentPublisher": "Demo",
  "ComponentConfiguration": {
    "DefaultConfiguration": {
      "accessControl": {
        "aws.greengrass.ipc.mqttproxy":{
          "${var.component_name}:mqttproxy:1": {
            "policyDescription": "Allows access to publish to all topics.",
            "operations": ["aws.greengrass#PublishToIoTCore"],
            "resources": ["*"]
          }
        }
      }
    }
  },
  "Manifests": [
    {
      "Platform": {
        "os": "linux" 
      },
      "Lifecycle": {
        "Install": "pip3 install --user -r {artifacts:path}/requirements.txt",
        "Run": "python3 -u {artifacts:path}/main.py",
        "Setenv" : {
          "TARGET_IOT_TOPIC": "${var.target_iot_topic}"
        }
      },
    "Artifacts": [
            {
                "URI": "s3://${local.artifact_bucket}/${aws_s3_object.main.id}"
            },
            {
                "URI": "s3://${local.artifact_bucket}/${aws_s3_object.requirements_txt.id}"
            }
      ]
    }
  ]
}
EOF
}
