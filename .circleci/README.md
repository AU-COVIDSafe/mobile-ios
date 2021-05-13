
## Introduction

CircleCI has a workflow configured to build and upload UAT builds once a merge is done to the dev branch. In the same way, there is a workflow for production and it runs when a merge is done to the master branch.

Fastlane is used to build and distribute the app.


## Fastlane Configuration

The approach taken for the app build and distribution was to provide the `provisioning profile` and the `certificate` manually rather than retrieving it automatically from appstore connect. For this, environment variables are set with the required values for both UAT and PROD.

This aliviates the requirements for authentication and interaction with the appstore leaving upload as the only outstanding task in the lanes. With fastlane's `pilot` we upload the app to TestFlight using application specific password, this action **requires** both `apple_id` and `skip_waiting_for_build_processing`. For more information see https://docs.fastlane.tools/actions/upload_to_testflight/#use-an-application-specific-password-to-upload

Note: Build numbers need to be set correctly on merge otherwise the upload will fail. In order to automate the build number update it is recomended to use an api_key.

### Lanes

There are 2 lanes defined per app build (UAT and PROD):

- import_uat_distribution_certificate: This lane will decode and install the needed provisioning profile and signing certificate for the UAT build.
- import_distribution_certificate: This lane will decode and install the needed provisioning profile and signing certificate for the PROD build.
- beta: This lane will build and upload the UAT build to testflight
- release: This lane will build and upload the PROD build to testflight

## CircleCI Project Configuration

The following environment variables need to be set in the CircleCI web console project configuration.


- APP_STORE_UAT_PROFILE_B64: Base64 encoded provisioning profile to use with UAT builds
- DISTRIBUTION_UAT_P12_B64: Base64 encoded distribution certificate to use with UAT builds
- DISTRIBUTION_UAT_P12_PASSWORD: Password for the UAT certificate above.
- APPLE_ID_UAT: This is the apps apple id. Can be found in appstore connect under App information -> General information.

- APP_STORE_PROFILE_B64: Base64 encoded provisioning profile to use with UAT builds
- DISTRIBUTION_P12_B64: Base64 encoded distribution certificate to use with UAT builds
- DISTRIBUTION_P12_PASSWORD: Password for the UAT certificate above.
- APPLE_ID: This is the apps apple id. Can be found in appstore connect under App information -> General information.

- FASTLANE_USER: App store connect user
- FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD: Application specific password generated for Fastlane. This is account specific rather than app specific, share the same for UAT and PROD. For more information on how to generate the password see https://docs.fastlane.tools/best-practices/continuous-integration/#method-3-application-specific-passwords


To get a base64 encoded string of the desired secret run 

```
openssl base64 -A -in "filename.extension"
```
