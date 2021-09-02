# Building images for deployment

Terraform deploys pre-built images that contain:

* Image Builder software (osbuild + osbuild-composer)
* Additional dependencies
* Monit and monit configuration
* Other system configuration

At this time, these images are built using [Packer] in the [image-builder-packer] repository.

> You may be thinking: *Why Packer?* That's a good question. This design choice
allowed us to move quickly on the deployment since it's difficult to build
images for as service that builds images when the service is not online yet.
It would be a great idea to change this later.

[Packer]: https://www.packer.io/
[image-builder-packer]: https://github.com/osbuild/image-builder-packer

## Updating images

Start by changing the Ansible code within the [image-builder-packer] repository
to include your updates. Make a pull request against the `main` branch in the
[image-builder-packer] repository and ensure the GitHub Actions CI completes
successfully.

After the change is reviewed and merged, monitor the image build in the
[image-builder-packer Actions tab]. The build output at the end will include
the identifying tags for the images. It should look like this:

```
Adding tag: "osbuild_commit": "20a142d8f9b8b5d0a69f4d91631dc94118d209ca"
Adding tag: "AppCode": "IMGB-001"
Adding tag: "Name": "imagebuilder-service-image-20210217133102"
Adding tag: "composer_commit": "a85511c6de917e60952832fda4c5b5e1f7c3857f"
Adding tag: "imagebuilder_packer_commit": "208b99189cd76145e97f99331230d3f4adcb03a8"
```

These tags are used by Terraform to identify the images it deploys.

## Deploying new images

There are two possible scenarios here:

1. You updated the image with new osbuild/osbuild-composer versions
1. You updated the image but the osbuild/osbuild-composer versions stayed the
   same

If you updated the osbuild/osbuild-composer versions, make the appropriate
changes to the `terraform.tfvars.json` file in `imagebuilder-terraform` to use
the new SHAs for osbuild and osbuild-composer. Go through the normal review
and merging steps used for all PRs against imagebuilder-terraform.

If you updated the image itself but the osbuild/osbuild-composer versions
remained the same, you have some options. One option is to  simply wait until
the next time that osbuild and osbuild-composer need to be updated and your
changes will deploy with those.

However, if you need to deploy your changes immediately, you can go to the
[imagebuilder-terraform Actions tab] and re-run the last action for the `main`
branch. Terraform will see the new image in AWS and deploy it automatically.
You can repeat the process with the last action in the `stable` branch when
you are ready to deploy to production.

> 🤔 NOTE: The process of updating an image without updating osbuild/osbuild-composer needs to be improved in the future.

[image-builder-packer Actions tab]: https://github.com/osbuild/image-builder-packer/actions
[imagebuilder-terraform Actions tab]: https://github.com/osbuild/imagebuilder-terraform/actions
