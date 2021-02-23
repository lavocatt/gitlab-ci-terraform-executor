# Keeping Terraform content organized

Terraform automatically picks up any content found in files that end in `.tf`,
so we can organize our content in a way that makes sense for us. It also
handles dependencies on its own, so we can put our content in any file, in any
order.

The goal of the repository is to make it easy for us to manage our own
infrastructure, so Terraform content should be arranged in a way that
**benefits us the most**.

## Shared infrastructure

Certain infrastructure primitives at AWS are used by multiple parts of our
deployment and those should be kept together. For example, VPC security groups
and Cloudwatch log groups are used by various instances throughout the
deployment.

These shared infrastructure items should be kept together based on the
services that they use. You can find almost all of the VPC-related
infrastructure in `vpc.tf` and that infrastructure is used in various places
in the deployment. You can find most of the shared IAM roles and policies
within `iam-external.tf` and `iam-internal.tf`.

## Deployment-specific infrastructure

Some infrastructure is specific to a particular part of the deployment, such
as the configuration for external worker fleets in
`workers-fleet-external.tf`. Try to keep infrastructure that is specific to
part of the deployment in these files.

As an example, if there is an IAM policy that needs to be set for part of the
deployment, put that configuration in the file with the majority of that
deployment configuration. If the IAM policy could be used system-wide by
multiple parts of the deployment, consider putting it in a file with other
system-wide IAM policies.

## Organizing content within each file

Try to keep related configuration together in each file. For example, if IAM
policies are required for part of the deployment, keep the configuration
ordered together in a way that makes sense to read top down. This order is
ideal:

1. Define IAM policy in JSON
1. Load the JSON into IAM to create a policy
1. Create an IAM role
1. Attach the policy to the role

This makes it easy to read top-down and understand how each step fits
together. Some files have commented blocks that break up the different
services required for certain parts of the deployment. Try to maintain that
separation whenever possible.
