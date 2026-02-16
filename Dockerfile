# -------------------------------
# Stage 1: Download everything
# -------------------------------
FROM curlimages/curl:7.76.1 AS downloader

ARG BASEURL=https://app.harness.io/public/shared/delegates
ARG DELEGATEVERSION
ARG TARGETARCH=amd64

WORKDIR /downloads

# Delegate JAR
RUN curl -s -L -o delegate.jar \
    $BASEURL/$DELEGATEVERSION/delegate.jar \
 && [ "$(stat -c%s delegate.jar)" -ge 104857600 ] \
 || (echo "Failed to download delegate.jar or delegate.jar is corrupted" && exit 1)

# Client tools
RUN set -eux; \
  mkdir -p client-tools; \
  \
  mkdir -p client-tools/kubectl/v1.33.5 && \
  curl -f -s -L -o client-tools/kubectl/v1.33.5/kubectl \
    https://app.harness.io/public/shared/tools/kubectl/release/v1.33.5/bin/linux/$TARGETARCH/kubectl; \
  \
  mkdir -p client-tools/helm/v3.13.3 && \
  curl -f -s -L -o client-tools/helm/v3.13.3/helm \
    https://app.harness.io/public/shared/tools/helm/release/v3.13.3/bin/linux/$TARGETARCH/helm; \
  \
  mkdir -p client-tools/harness-helm-post-renderer/v0.1.6 && \
  curl -f -s -L -o client-tools/harness-helm-post-renderer/v0.1.6/harness-helm-post-renderer \
    https://app.harness.io/public/shared/tools/harness-helm-post-renderer/release/v0.1.6/bin/linux/$TARGETARCH/harness-helm-post-renderer; \
  \
  mkdir -p client-tools/go-template/v0.4.9 && \
  curl -f -s -L -o client-tools/go-template/v0.4.9/go-template \
    https://app.harness.io/public/shared/tools/go-template/release/v0.4.9/bin/linux/$TARGETARCH/go-template; \
  \
  mkdir -p client-tools/harness-pywinrm/v0.4-dev && \
  curl -f -s -L -o client-tools/harness-pywinrm/v0.4-dev/harness-pywinrm \
    https://app.harness.io/public/shared/tools/harness-pywinrm/release/v0.4-dev/bin/linux/$TARGETARCH/harness-pywinrm; \
  \
  mkdir -p client-tools/chartmuseum/v0.16.3 && \
  curl -f -s -L -o client-tools/chartmuseum/v0.16.3/chartmuseum \
    https://app.harness.io/public/shared/tools/chartmuseum/release/v0.16.3/bin/linux/$TARGETARCH/chartmuseum; \
  \
  mkdir -p client-tools/tf-config-inspect/v1.3 && \
  curl -f -s -L -o client-tools/tf-config-inspect/v1.3/terraform-config-inspect \
    https://app.harness.io/public/shared/tools/terraform-config-inspect/release/v1.3/bin/linux/$TARGETARCH/terraform-config-inspect; \
  \
  mkdir -p client-tools/oc/v4.17.30 && \
  curl -f -s -L -o client-tools/oc/v4.17.30/oc \
    https://app.harness.io/public/shared/tools/oc/release/v4.17.30/bin/linux/$TARGETARCH/oc; \
  \
  mkdir -p client-tools/scm/079a7a785 && \
  curl -f -s -L -o client-tools/scm/079a7a785/scm \
    https://app.harness.io/public/shared/tools/scm/release/079a7a785/bin/linux/$TARGETARCH/scm; \
  \
  mkdir -p client-tools/kubelogin/v0.1.9 && \
  curl -f -s -L -o client-tools/kubelogin/v0.1.9/kubelogin \
    https://app.harness.io/public/shared/tools/kubelogin/release/v0.1.9/bin/linux/$TARGETARCH/kubelogin; \
  \
  mkdir -p client-tools/harness-credentials-plugin/v0.1.1 && \
  curl -f -s -L -o client-tools/harness-credentials-plugin/v0.1.1/harness-credentials-plugin \
    https://app.harness.io/public/shared/tools/harness-credentials-plugin/release/v0.1.1/bin/linux/$TARGETARCH/harness-credentials-plugin; \
  \
  mkdir -p client-tools/hcli/68e8ada && \
  curl -f -s -L -o client-tools/hcli/68e8ada/hcli \
    https://app.harness.io/public/shared/tools/hcli/release/68e8ada/bin/linux/$TARGETARCH/hcli; \
  \
  curl -f -s -L -o jattach \
    https://app.harness.io/public/shared/tools/jattach/release/v2.2/bin/linux/$TARGETARCH/jattach; \
  \
  chmod +x client-tools/**/** jattach

# -------------------------------
# Stage 2: Runtime image
# -------------------------------
FROM registry.redhat.io/ubi9/ubi-stig:9.7

LABEL name="harness/delegate" \
      vendor="Harness" \
      maintainer="Harness"

# RUN echo -e '#!/bin/sh\nexec /usr/bin/microdnf -y "$@"' > /usr/local/bin/microdnf \
#  && chmod +x /usr/local/bin/microdnf

RUN useradd -u 1001 -g 0 harness \
 && mkdir -p /opt/harness-delegate

COPY immutable-scripts /opt/harness-delegate/
COPY fips-scripts /opt/harness-delegate/

WORKDIR /opt/harness-delegate

COPY --from=eclipse-temurin:17.0.17_10-jre-ubi9-minimal /opt/java/openjdk/ /opt/java/openjdk/

# Copy downloaded artifacts
COPY --from=downloader /downloads/delegate.jar /opt/harness-delegate/delegate.jar
COPY --from=downloader /downloads/client-tools /opt/harness-delegate/client-tools
COPY --from=downloader /downloads/jattach /opt/java/openjdk/bin/jattach

RUN chmod -R 775 /opt/harness-delegate \
 && chgrp -R 0 /opt/harness-delegate \
 && chown -R 1001 /opt/harness-delegate \
 && chown -R 1001 /opt/java/openjdk/lib/security/cacerts

ENV LANG=en_US.UTF-8
ENV HOME=/opt/harness-delegate
ENV CLIENT_TOOLS_DOWNLOAD_DISABLED=true
ENV INSTALL_CLIENT_TOOLS_IN_BACKGROUND=true
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="$JAVA_HOME/bin/jattach:$JAVA_HOME/bin:${PATH}"
ENV DELEGATE_HTTP_PORT=${DELEGATE_HTTP_PORT:-3460}

RUN /opt/harness-delegate/download-bc.sh

USER 1001

HEALTHCHECK --interval=10s --timeout=1s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:${DELEGATE_HTTP_PORT:-3460}/api/health

ENTRYPOINT ["./setup-bc.sh"]
CMD ["./start.sh"]
