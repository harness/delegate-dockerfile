
# Delegate Dockerfile

This repository provides the Harness delegate Dockerfile. You can use this Dockerfile to build custom delegate images.

The repository includes the following versions of the delegate Dockerfile. Please note that if you are building and using your own images then turn auto upgrade off for kubernetes delegates. Read documentation at https://developer.harness.io/docs/platform/Delegates/install-delegates/delegate-upgrades-and-expiration

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

## Dockerfile-ubuntu

Use `Dockerfile-ubuntu` to create delegate delegate images which are ubuntu based. This image includes all the same tools of default Dockerfile

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
latest_version=$(curl -X GET 'https://app.harness.io/gateway/ng/api/delegate-setup/latest-supported-version?accountIdentifier=<replace_with_account_ideentifier>' -H 'x-api-key: <replace_with_api_key>')

# Extract the build version using jq and some basic string manipulation
build_version=$(echo $latest_version | jq -r '.resource.latestSupportedVersion' | cut -d '.' -f 3)

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
## Build Image with Custom CA certs
To support a use case where your delegate requires custom CA to be working, but you cannot run delegate container with root user.

The solution is to add custom CA bundle files to the delegate image and run load_certificates.sh script on these CA bundle files.

The `load_certificates.sh` script will make sure
1. Your CA certificates are added to delegate's Java truststore located at `$JAVA_HOME/lib/security/cacerts`
2. Your CA certificates are added to Redhat OS trust store.
3. Your CA certificates will be applied to Harness CI pipelines.

To achieve this, please follow the following steps to build your custom delegate image.
1. Prepare all your CA certificates and put them under a local directory.
2. Add the two lines below into your delegate docker file. Replace the paths with your choices. Please put them right before the line of `USER 1001`, because it requires root user to run the script.
3. Build your docker image

The two lines below will copy all the certificates from local ./my-custom-ca to /opt/harness-delegate/my-ca-bundle/ directory inside the container.

```yaml
USER root
  
RUN curl -s -L -o delegate.jar $BASEURL/$DELEGATEVERSION/delegate.jar

+ COPY <path to the directory of my local certs> <path to the directory of certs inside the container>

+ RUN bash -c "/opt/harness-delegate/load_certificates.sh <path to the directory of certs inside the container>"

USER 1001
```
Note that 
1. please DO NOT copy your certificates into folder at `/opt/harness-delegate/ca-bundle`, because this is a reserved folder used for installing additional certificates to at the time of starting a delegate.
2. Set user to root before running the load_certificates.sh script. Then set it back to normal user after.
