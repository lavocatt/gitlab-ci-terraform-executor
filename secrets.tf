##############################################################################
## SECRETS

# Set up secrets for Brew composer and workers.
resource "aws_secretsmanager_secret" "brew_secrets" {
  name        = "brew_secrets"
  description = "Secrets for the Brew composer and workers"

  tags = merge(
    var.imagebuilder_tags, { Name = "Image Builder Brew secrets" },
  )
}
