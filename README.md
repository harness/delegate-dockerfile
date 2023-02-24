
# Delegate Dockerfile

This repository provides the Harness delegate Dockerfile. You can use this Dockerfile to build custom delegate images.

The repository includes the following versions of the Dockerfile.

## Dockerfile

Dockerfile: Through this you can create the delegate image with tools. We have added below tools by default in this image.

  - `kubectl` v1.24.3
  - `helm` v2.13.1 
  - `helm` v3.1.2
  - `helm` v3.8.0 
  - `go-template` v0.4.1 
  - `harness-pywinrm` v0.4-dev 
  - `chartmuseum` v0.15.0 
  - `tf-config-inspect` v1.1
  - `oc` v4.2.16
  - `kustomize` v4.5.4
  - `scm`

## Dockerfile-minimal

Use Dockerfile-minimal to create delegate images without tools. This image includes only the SCM client tool.

:::note
You can also replace existing tools with those that you prefer to use for CI/CD.
:::

## Build the image

To build your custom image, use the appropriate command:

### Dockerfile

```
- docker build -t {TAG} -f Dockerfile
```

### Dockerfile-minimal

```
- docker build -t {TAG} -f Dockerfile-minimal
```
