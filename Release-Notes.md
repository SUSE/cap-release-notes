# Release Notes SUSE Cloud Application Platform 1.0

These are the release notes for SUSE Cloud Application Platform 1.0. It contains additional information specific to the current release. See the [Deployment Guide](https://www.suse.com/documentation/cloud-application-platform-1/) for details information how to deploy the product.

## Known issues

* Do not set the `mysql` or `diego_access` roles to more than one instance each in HA configurations. Doing so can cause problems with subsequent upgrades which could lead to loss of data. Scalability of these roles will be enabled in an upcoming maintenance release.
