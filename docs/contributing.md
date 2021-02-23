# Contributing to Image Builder's Terraform configuration

All of the terraform configuration in this repository is written in *[HCL]*, a
syntax used by most products from Hashicorp. You can read all about the syntax
structure in terraform's [Configuration Syntax] documentation.

[HCL]: https://github.com/hashicorp/hcl/blob/hcl2/hclsyntax/spec.md
[Configuration Syntax]: https://www.terraform.io/docs/language/syntax/configuration.html

## First steps

[Download Terraform] version 0.14.0 or higher. Add it to your `~/.local/bin`
directory if you need an easy way to execute it from anywhere on your system.

[Download Terraform]: https://www.terraform.io/downloads.html

## Automatic formatting

Once you write new terraform configuration or update the existing
configuration, run `terraform fmt` to ensure the indentation and all
formatting is correct. The GitHub Actions CI is configured to check the
formatting when you make a pull request, but running `terraform fmt` first on
your local machine should save you some time.

## Making a pull request

Add your changes and commit them as you normally would. Include an explanation
of your change what you hope to achieve. Propose your PR against the `main`
branch since this branch is used to deploy our *staging* environment. The
GitHub Actions CI will install and configure terraform, check the formatting,
and run a `terraform plan` with your changes.

> 💣 **Carefully review the plan output from terraform to ensure that the changes
are correct.** If you are only changing an AWS IAM policy in your PR, but you
see that terraform wants to rebuild instances or redeploy a spot fleet, go
back to your change and determine why terraform wants to make those changes.

## Reviews

As a reviewer, ensure that the PR does a few things:

1. The changes proposed in the `terraform plan` must match the changes
   proposed in the PR. (No more, no less.)
1. Any changes must not hard-code any deployment-specific data. For example,
   hard-coding a region, like `us-east-1`, should not be permitted. Use a
   `variable` or `data` lookup block and reference the data or variable
   elsewhere in the code.
1. Changes should include inline comments which explain what each
   configuration block does.

Once the plan is verified and the above criteria are met, merge the code into
the `main` branch. You can watch the changes apply to staging by going to the
[Actions tab] in the repository.

[Actions tab]: https://github.com/osbuild/imagebuilder-terraform/actions

## Updating production

Update the production deployment only after the deployment to staging has
completed successfully. Verify that the changes are working in staging as
well.

Create a new branch, cherry-pick the change into that branch (using `git
cherry-pick <SHA>`), and push the branch. Make a pull request against `stable`
and follow the same review process shown above.

After merging, verify that the deployment to the production environment
succeeded using the [Actions tab] in the repository.
