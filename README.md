# ⛅ Image Builder Terraform resources

This repostiory contains all of the Terraform resources needed to run Image
Builder within AWS.

## What is the goal of this repository?

Complex cloud deployments involve plenty of interlocking parts that must be
managed over time. We can specify exactly how our cloud deployment should look
using Terraform and it does the heavy lifting for us.

We also gain the benefit of being able to tear down and rebuild the entire
deployment in minutes. Migrating to another region involves making a pull
request with some changes and merging those changes.

## Making changes

1. [Download Terraform] version 0.13.5 or higher.
1. Make your changes and run `terraform fmt` to tidy the configuration.
1. Push your changes to a branch in this repository and make a pull request.
1. GitHub Actions runs Terraform to check the formatting and run a deployment
   plan.
1. **Examine the plan carefully to ensure the right changes will be made.** If
   Terraform's output shows that it plans to do something unexpected, revise
   your pull request until the plan looks accurate.
1. Once the PR is reviewed and merge into `main`, GitHub Actions runs
   Terraform once more to deploy the infrastructure based on the plan.
1. Your changes are now deployed!

[Download Terraform]: https://www.terraform.io/downloads.html

## Organizing Terraform configuration

Configuration sprawl can be a challenge, so try to keep similar configuration
together when you can.

As an example, `data.tf` contains lots of lookups for resources that already
exist in AWS. We don't create any resources there, but do we do lookup various
bits of data, such as VPC IDs or IAM ARNs, that are needed in other parts of
the configuration.

Provide a brief comment above each resource section and provide additional
comments within the section whenever possible.

## Branches

This repository has two branches which correspond to different deployment
workspaces:

* `main` - Corresponds to the `staging` workspace in Terraform and the staging
  deployment inside AWS.
* `stable` - Corresponds to the `stable` workspace in Terraform and the stable
  deployment inside AWS.

All pull requests for new changes must be made against `main` (and that is the
default branch in GitHub). Once the change merges and the changes are verified
in AWS, the change can be proposed for the `stable` branch.
