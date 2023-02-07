variable "device_name" {
  type = string
}
variable "profile" {
  type = string
}
variable "region" {
  type = string
}
variable "bucket" {
  type = string
}
variable "greengrass_version" {
  type = string
}
variable "config_dir" {
  type = string
}
variable "artifacts_dir" {
  type    = string
  default = "artifacts"
}
variable "component_name" {
  type = string
}
variable "component_version" {
  type = string
}
variable "target_iot_topic" {
  type = string
}
