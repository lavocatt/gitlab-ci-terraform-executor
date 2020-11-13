# Create S3 buckets for stage and prod where imagebuilder workers will upload
# images to import into EC2.
resource "aws_s3_bucket" "imagebuilder-stage" {
  bucket = "imagebuilder-service-stage"
  acl    = "private"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder S3 bucket for Stage" },
  )
}
resource "aws_s3_bucket" "imagebuilder-prod" {
  bucket = "imagebuilder-service-prod"
  acl    = "private"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder S3 bucket for Prod" },
  )
}
