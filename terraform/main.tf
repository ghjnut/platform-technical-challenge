data "aws_caller_identity" "current" {}

# TODO a little bit of funkiness promoting artifacts if there's a repo per env
resource "aws_ecr_repository" "app" {
  name = "inception-health/app"

  # TODO enable encryption
  #encryption_configuration = {
  #  encryption_type = "KMS"
  #  kms_key =
  #}

  # TODO should be enabled
  #image_scanning_configuration {
  #  scan_on_push = true
  #}
}
