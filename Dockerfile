# Copyright 2022 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

FROM redhat/ubi8-minimal:8.10

LABEL name="harness/delegate" \
      vendor="Harness" \
      maintainer="Harness"

RUN microdnf update --nodocs --setopt=install_weak_deps=0 \
  && microdnf install --nodocs \
    procps \
    hostname \
    lsof \
    findutils \
    tar \
    gzip \
    git \
    shadow-utils \
    glibc-langpack-en \
  && useradd -u 1001 -g 0 harness \
  && microdnf remove shadow-utils \
  && microdnf clean all \
  && rm -rf /var/cache/yum \
  && mkdir -p /opt/harness-delegate/

COPY immutable-scripts /opt/harness-delegate/

WORKDIR /opt/harness-delegate

COPY --from=eclipse-temurin:17.0.7_7-jre-ubi9-minimal /opt/java/openjdk/ /opt/java/openjdk/

ENV LANG=en_US.UTF-8
ENV HOME=/opt/harness-delegate
ENV CLIENT_TOOLS_DOWNLOAD_DISABLED=true
ENV INSTALL_CLIENT_TOOLS_IN_BACKGROUND=true
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="$JAVA_HOME/bin:${PATH}"

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}
ARG BASEURL=https://app.harness.io/public/shared/delegates
ARG DELEGATEVERSION

RUN set -o pipefail \
  && mkdir -m 777 -p client-tools/kubectl/v1.28.7 \
  && curl -f -s -L -o client-tools/kubectl/v1.28.7/kubectl https://app.harness.io/public/shared/tools/kubectl/release/v1.28.7/bin/linux/$TARGETARCH/kubectl || { echo "Failed to download kubectl"; exit 1; } \
  && mkdir -m 777 -p client-tools/helm/v3.13.3 \
  && curl -f -s -L -o client-tools/helm/v3.13.3/helm https://app.harness.io/public/shared/tools/helm/release/v3.13.3/bin/linux/$TARGETARCH/helm || { echo "Failed to download helm"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-helm-post-renderer/v0.1.3 \
  && curl -f -s -L -o client-tools/harness-helm-post-renderer/v0.1.3/harness-helm-post-renderer https://app.harness.io/public/shared/tools/harness-helm-post-renderer/release/v0.1.3/bin/linux/$TARGETARCH/harness-helm-post-renderer || { echo "Failed to download harness-helm-post-renderer"; exit 1; } \
  && mkdir -m 777 -p client-tools/go-template/v0.4.5 \
  && curl -f -s -L -o client-tools/go-template/v0.4.5/go-template https://app.harness.io/public/shared/tools/go-template/release/v0.4.5/bin/linux/$TARGETARCH/go-template || { echo "Failed to download go-template"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-pywinrm/v0.4-dev \
  && curl -f -s -L -o client-tools/harness-pywinrm/v0.4-dev/harness-pywinrm https://app.harness.io/public/shared/tools/harness-pywinrm/release/v0.4-dev/bin/linux/$TARGETARCH/harness-pywinrm || { echo "Failed to download harness-pywinrm"; exit 1; } \
  && mkdir -m 777 -p client-tools/chartmuseum/v0.15.0 \
  && curl -f -s -L -o client-tools/chartmuseum/v0.15.0/chartmuseum https://app.harness.io/public/shared/tools/chartmuseum/release/v0.15.0/bin/linux/$TARGETARCH/chartmuseum || { echo "Failed to download chartmuseum"; exit 1; } \
  && mkdir -m 777 -p client-tools/tf-config-inspect/v1.2 \
  && curl -f -s -L -o client-tools/tf-config-inspect/v1.2/terraform-config-inspect https://app.harness.io/public/shared/tools/terraform-config-inspect/v1.2/linux/$TARGETARCH/terraform-config-inspect || { echo "Failed to download terraform-config-inspect"; exit 1; } \
  && mkdir -m 777 -p client-tools/oc/v4.15.25 \
  && curl -f -s -L -o client-tools/oc/v4.15.25/oc https://app.harness.io/public/shared/tools/oc/release/v4.15.25/bin/linux/$TARGETARCH/oc || { echo "Failed to download oc"; exit 1; } \
  && mkdir -m 777 -p client-tools/scm/34a795585 \
  && curl -f -s -L -o client-tools/scm/34a795585/scm https://app.harness.io/public/shared/tools/scm/release/34a795585/bin/linux/$TARGETARCH/scm || { echo "Failed to download scm"; exit 1; } \
  && mkdir -m 777 -p client-tools/kubelogin/v0.1.1 \
  && curl -f -s -L -o client-tools/kubelogin/v0.1.1/kubelogin https://app.harness.io/public/shared/tools/kubelogin/release/v0.1.1/bin/linux/$TARGETARCH/kubelogin || { echo "Failed to download kubelogin"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-credentials-plugin/v0.1.0 \
  && curl -f -s -L -o client-tools/harness-credentials-plugin/v0.1.0/harness-credentials-plugin https://app.harness.io/public/shared/tools/harness-credentials-plugin/release/v0.1.0/bin/linux/$TARGETARCH/harness-credentials-plugin || { echo "Failed to download harness-credentials-plugin"; exit 1; } \
  && curl -f -s -L -o $JAVA_HOME/bin/jattach https://app.harness.io/public/shared/tools/jattach/release/v2.2/bin/linux/$TARGETARCH/jattach || { echo "Failed to download jattach"; exit 1; } \
  && chmod +x $JAVA_HOME/bin/jattach \
  && chmod -R 775 /opt/harness-delegate \
  && chgrp -R 0 /opt/harness-delegate \
  && chown -R 1001 /opt/harness-delegate \
  && chown -R 1001 $JAVA_HOME/lib/security/cacerts

ENV PATH="$JAVA_HOME/bin/jattach:${PATH}"
ENV PATH=/opt/harness-delegate/client-tools/kubectl/v1.28.7/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/go-template/v0.4.5/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/chartmuseum/v0.15.0/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/tf-config-inspect/v1.2/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/helm/v3.13.3/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/harness-helm-post-renderer/v0.1.3/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/oc/v4.15.25/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/kubelogin/v0.1.1/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/harness-credentials-plugin/v0.1.0/:$PATH

RUN curl -s -L -o delegate.jar $BASEURL/$DELEGATEVERSION/delegate.jar

USER 1001

CMD [ "./start.sh" ]
