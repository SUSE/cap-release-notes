# Release Notes SUSE Cloud Application Platform 1.0

These are the release notes for SUSE Cloud Application Platform 1.0. It contains additional information specific to the current release. See the [Deployment Guide](https://www.suse.com/documentation/cloud-application-platform-1/) for details information how to deploy the product.

## Known issues

* There is a known problem with HA. So we've reverted to being just elastic, meaning no roles should be scaled except the Diego cell and the Router. Scaling the other roles will be possible with a future maintenance update.
