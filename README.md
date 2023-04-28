
# Delegate Dockerfile

This repository provides the Harness delegate Dockerfile. You can use this Dockerfile to build custom delegate images.

The repository includes the following versions of the delegate Dockerfile.

## Dockerfile

Use `Dockerfile` to create the delegate image with tools. This image includes the following tools by default.

  - `kubectl` v1.24.3
  - `helm` v2.13.1 
  - `helm` v3.1.2
  - `helm` v3.8.0 
  - `go-template` v0.4.2 
  - `harness-pywinrm` v0.4-dev 
  - `chartmuseum` v0.15.0 
  - `tf-config-inspect` v1.2
  - `oc` v4.2.16
  - `kustomize` v4.5.4
  - `scm`

## Dockerfile-minimal

Use `Dockerfile-minimal` to create delegate images without tools. This image includes only the SCM client tool.

:::note
You can also replace the existing tools with those that you prefer to use for CI/CD.
:::

## Build the image
For building the image you need two arguments
1. TARGETARCH (amd64/arm64) 
2. The build version of delegate 

You can get the build version that you should use for your account using the API documented at https://apidocs.harness.io/tag/Delegate-Setup-Resource#operation/publishedDelegateVersion

To learn about the support for delegate version and expiry policy visit https://developer.harness.io/docs/platform/Delegates/install-delegates/delegate-upgrades-and-expiration#delegate-expiration-policy

Here is an example script to get the version which uses `curl` to fetch and `jq` to parse 

```
latest_version=$(curl -i -X GET 'https://app.harness.io/gateway/ng/api/delegate-setup/latest-supported-version?accountIdentifier=<replace_with_account_ideentifier>' -H 'x-api-key: <replace_with_api_key>')

# Extract the build version using jq and some basic string manipulation
build_version=$(echo $response | jq -r '.resource.latestSupportedVersion' | cut -d '.' -f 3)

# Print the build version
echo $build_version
```
To build your custom image, use the appropriate command and use the build_version you got from the above command:

### Dockerfile

```
docker build -t {TAG} -f Dockerfile --build-arg TARGETARCH=amd64 --build-arg DELEGATEVERSION=<version_from_previous_step> .
```

### Dockerfile-minimal

```
docker build -t {TAG} -f Dockerfile-minimal --build-arg TARGETARCH=amd64 --build-arg DELEGATEVERSION=<version_from_previous_step> .
```
