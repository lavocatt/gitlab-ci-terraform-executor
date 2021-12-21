# Building images for deployment

Terraform deploys pre-built images that contain:

* Image Builder software (osbuild + osbuild-composer)
* Additional dependencies
* Monit and monit configuration
* Other system configuration

At this time, these images are built using [Packer] in the [osbuild-composer]
repository.

> You may be thinking: *Why Packer?* That's a good question. This design choice
allowed us to move quickly on the deployment since it's difficult to build
images for as service that builds images when the service is not online yet.
It would be a great idea to change this later.

[Packer]: https://www.packer.io/
[osbuild-composer]: https://github.com/osbuild/osbuild-composer

## Deploying new images

Just edit osbuild-composer SHA in `terraform.tfvars.json` and send a PR
against image-builder-terraform.
