# ⛅ Image Builder Terraform resources

This repostiory contains all of the Terraform resources needed to run Image
Builder within AWS.

All of the documentation is inside the `docs` directory. You can directly
access handy instructions via the links below:

* [How do I contribute to the repository?](docs/contributing.md)
* [How do I keep Terraform content organized?](docs/organization.md)
* [How do I build the images that Terraform deploys?](docs/building-images.md)

## What is the goal of this repository?

Complex cloud deployments involve plenty of interlocking parts that must be
managed over time. We can specify exactly how our cloud deployment should look
using Terraform and it does the heavy lifting for us.

We also gain the benefit of being able to tear down and rebuild the entire
deployment in minutes. Migrating to another region involves making a pull
request with some changes and merging those changes.
