fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS

- import_uat_distribution_certificate: This lane will decode and install the needed provisioning profile and signing certificate for the UAT build.
- import_distribution_certificate: This lane will decode and install the needed provisioning profile and signing certificate for the PROD build.
- beta: This lane will build and upload the UAT build to testflight
- release: This lane will build and upload the PROD build to testflight

