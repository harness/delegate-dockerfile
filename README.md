
# Delegate Dockerfile

This repo is used to get the delegate dockerfile. Through which you can build your own custom delegate images.

There are 2 dockerfiles for delegate in this repo:
1: Dockerfile: Through this you can create the delegate image with tools. We have added below tools by default in this image.
  - kubectl v1.24.3
  - helm v2.13.1 
  - helm v3.1.2
  - helm v3.8.0 
  - go-template v0.4.1 
  - harness-pywinrm v0.4-dev 
  - chartmuseum v0.15.0 
  - tf-config-inspect v1.1
  - oc v4.2.16
  - kustomize v4.5.4
  - scm
2: Dockerfile-minimal: Through this you can create the delegate image without tools. There is only one client-tool (SCM) is added.

Note: You can remove the tools which are not of your use and can add what you want to use it for CD/CI.

Commands to bake the images:
- docker build -t {TAG} -f Dockerfile
- docker build -t {TAG} -f Dockerfile-minimal
