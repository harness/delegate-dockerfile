# Copyright 2022 Harness Inc. All rights reserved.
# Use of this source code is governed by the PolyForm Free Trial 1.0.0 license
# that can be found in the licenses directory at the root of this repository, also available at
# https://polyformproject.org/wp-content/uploads/2020/05/PolyForm-Free-Trial-1.0.0.txt.

# Base registry for container images
# - Leave unset (default) for public Docker Hub images
# - For internal builds: MUST end with trailing slash
#   Correct:   --build-arg BASE_REGISTRY=harness0.harness.io/oci/docker_artifacts/
#   Incorrect: --build-arg BASE_REGISTRY=harness0.harness.io/oci/docker_artifacts
ARG BASE_REGISTRY

FROM ${BASE_REGISTRY}curlimages/curl:7.76.1 AS delegate-jar-downloader

ARG BASEURL=https://app.harness.io/public/shared/delegates
ARG DELEGATEVERSION

WORKDIR /downloads

RUN curl -s -L -o delegate.jar $BASEURL/$DELEGATEVERSION/delegate.jar && [ $(stat -c%s delegate.jar) -ge 104857600 ] || (echo "Failed to download delegate.jar or delegate.jar is corrupted" && exit 1)


FROM ${BASE_REGISTRY}redhat/ubi9-minimal:9.7

LABEL name="harness/delegate" \
      vendor="Harness" \
      maintainer="Harness"

RUN echo -e '#!/bin/sh\nexec /usr/bin/microdnf -y "$@"' > /usr/local/bin/microdnf \
  && chmod +x /usr/local/bin/microdnf

RUN microdnf update --nodocs --setopt=install_weak_deps=0 --nobest \
  && microdnf install --nodocs --nobest \
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

# eMudhra CA compromise (CVE-2026-111943/CVE-2026-91403): RHEL/UBI has not shipped a
# ca-certificates update that drops trust in the compromised roots ("AAA Certificate
# Services" and "emSign ECC Root CA - G3"), so distrust them explicitly. Matches by
# SHA-256 fingerprint, not by RHEL's display label, so a label rename can't make this
# step silently find nothing while the cert stays trusted. The final loop re-checks the
# generated bundle and only fails the build if either fingerprint is still trusted.
RUN microdnf install -y --nodocs openssl \
  && BUNDLE=/etc/pki/tls/certs/ca-bundle.crt \
  && AAA_FP="D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4" \
  && EMSIGN_FP="86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B" \
  && mkdir -p /etc/pki/ca-trust/source/blocklist /tmp/certsplit \
  && awk '/-----BEGIN CERTIFICATE-----/{n++; f="/tmp/certsplit/c" n ".pem"; a=1} a{print > f} /-----END CERTIFICATE-----/{a=0; close(f)}' "$BUNDLE" \
  && for f in /tmp/certsplit/*.pem; do \
       fp=$(openssl x509 -noout -fingerprint -sha256 -in "$f" | sed 's/.*=//; s/://g'); \
       case "$fp" in "$AAA_FP"|"$EMSIGN_FP") cp "$f" /etc/pki/ca-trust/source/blocklist/"$(basename "$f")" ;; esac; \
     done \
  && update-ca-trust extract \
  && rm -rf /tmp/certsplit && mkdir -p /tmp/certsplit \
  && awk '/-----BEGIN CERTIFICATE-----/{n++; f="/tmp/certsplit/c" n ".pem"; a=1} a{print > f} /-----END CERTIFICATE-----/{a=0; close(f)}' "$BUNDLE" \
  && for f in /tmp/certsplit/*.pem; do \
       fp=$(openssl x509 -noout -fingerprint -sha256 -in "$f" | sed 's/.*=//; s/://g'); \
       case "$fp" in \
         "$AAA_FP"|"$EMSIGN_FP") echo "FATAL: compromised eMudhra/AAA root ($fp) is still trusted" >&2; exit 1 ;; \
       esac; \
     done \
  && rm -rf /tmp/certsplit \
  && microdnf clean all \
  && rm -rf /var/cache/yum

COPY immutable-scripts /opt/harness-delegate/
COPY fips-scripts /opt/harness-delegate/

WORKDIR /opt/harness-delegate

COPY --from=eclipse-temurin:17.0.20_8-jre-ubi9-minimal /opt/java/openjdk/ /opt/java/openjdk/

ENV LANG=en_US.UTF-8
ENV HOME=/opt/harness-delegate
ENV CLIENT_TOOLS_DOWNLOAD_DISABLED=true
ENV INSTALL_CLIENT_TOOLS_IN_BACKGROUND=true
ENV JAVA_HOME=/opt/java/openjdk

# eMudhra CA compromise (CVE-2026-91403): no Temurin 17.0.21 image is published yet that
# drops trust in the compromised root, so explicitly delete it from cacerts. "AAA Certificate
# Services" is not present in this JRE's truststore (only the OS bundle trusts it), so only
# the eMudhra root needs removing here. Guarded by -list so a future JRE bump that already
# drops this alias (e.g. once 17.0.21 ships) doesn't fail the build; delete the whole step
# once the base image is actually on a JRE that ships the fix.
RUN ALIAS="cn_emsign_ecc_root_ca__g3,o_emudhra_technologies_limited,ou_emsign_pki,c_in [jdk]" \
  && if $JAVA_HOME/bin/keytool -list -alias "$ALIAS" -keystore $JAVA_HOME/lib/security/cacerts -storepass changeit >/dev/null 2>&1; then \
       $JAVA_HOME/bin/keytool -delete -alias "$ALIAS" -keystore $JAVA_HOME/lib/security/cacerts -storepass changeit; \
     fi

ENV PATH="$JAVA_HOME/bin:${PATH}"
ENV DELEGATE_HTTP_PORT=${DELEGATE_HTTP_PORT:-3460}

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}
ARG FIPS_ENABLED
ENV FIPS_ENABLED=${FIPS_ENABLED:-false}
ARG JAR_DOWNLOAD_BASE_URL=https://repo1.maven.org/maven2
ENV JAR_DOWNLOAD_BASE_URL=${JAR_DOWNLOAD_BASE_URL}

RUN set -o pipefail \
  && curl -f -s -L -o /usr/local/bin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-static-$TARGETARCH || { echo "Failed to download tini"; exit 1; } \
  && case "$TARGETARCH" in \
       amd64) echo "c5b0666b4cb676901f90dfcb37106783c5fe2077b04590973b885950611b30ee  /usr/local/bin/tini" | sha256sum -c - ;; \
       arm64) echo "eae1d3aa50c48fb23b8cbdf4e369d0910dfc538566bfd09df89a774aa84a48b9  /usr/local/bin/tini" | sha256sum -c - ;; \
       *) echo "Unsupported architecture for tini: $TARGETARCH"; exit 1 ;; \
     esac \
  && chmod +x /usr/local/bin/tini \
  && mkdir -m 777 -p client-tools/kubectl/v1.36.2 \
  && curl -f -s -L -o client-tools/kubectl/v1.36.2/kubectl https://app.harness.io/public/shared/tools/kubectl/release/v1.36.2/bin/linux/$TARGETARCH/kubectl || { echo "Failed to download kubectl"; exit 1; } \
  && mkdir -m 777 -p client-tools/helm/v3.21.4 \
  && curl -f -s -L -o client-tools/helm/v3.21.4/helm https://app.harness.io/public/shared/tools/helm/release/v3.21.4/bin/linux/$TARGETARCH/helm || { echo "Failed to download helm"; exit 1; } \
  && mkdir -m 777 -p client-tools/helm/v4.2.3 \
  && curl -f -s -L -o client-tools/helm/v4.2.3/helm4 https://app.harness.io/public/shared/tools/helm/release/v4.2.3/bin/linux/$TARGETARCH/helm4 || { echo "Failed to download helm4"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-helm-post-renderer/v0.2.5 \
  && curl -f -s -L -o client-tools/harness-helm-post-renderer/v0.2.5/harness-helm-post-renderer https://app.harness.io/public/shared/tools/harness-helm-post-renderer/release/v0.2.5/bin/linux/$TARGETARCH/harness-helm-post-renderer || { echo "Failed to download harness-helm-post-renderer"; exit 1; } \
  && chmod 755 client-tools/harness-helm-post-renderer/v0.2.5/harness-helm-post-renderer \
  && mkdir -m 777 -p client-tools/helm-plugins \
  && mkdir -m 777 -p client-tools/go-template/v0.4.16 \
  && curl -f -s -L -o client-tools/go-template/v0.4.16/go-template https://app.harness.io/public/shared/tools/go-template/release/v0.4.16/bin/linux/$TARGETARCH/go-template || { echo "Failed to download go-template"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-pywinrm/v0.4-dev \
  && curl -f -s -L -o client-tools/harness-pywinrm/v0.4-dev/harness-pywinrm https://app.harness.io/public/shared/tools/harness-pywinrm/release/v0.4-dev/bin/linux/$TARGETARCH/harness-pywinrm || { echo "Failed to download harness-pywinrm"; exit 1; } \
  && mkdir -m 777 -p client-tools/chartmuseum/v0.16.6 \
  && curl -f -s -L -o client-tools/chartmuseum/v0.16.6/chartmuseum https://app.harness.io/public/shared/tools/chartmuseum/release/v0.16.6/bin/linux/$TARGETARCH/chartmuseum || { echo "Failed to download chartmuseum"; exit 1; } \
  && mkdir -m 777 -p client-tools/oc/v4.22.16 \
  && curl -f -s -L -o client-tools/oc/v4.22.16/oc https://app.harness.io/public/shared/tools/oc/release/v4.22.16/bin/linux/$TARGETARCH/oc || { echo "Failed to download oc"; exit 1; } \
  && mkdir -m 777 -p client-tools/scm/17e330b20 \
  && curl -f -s -L -o client-tools/scm/17e330b20/scm https://app.harness.io/public/shared/tools/scm/release/17e330b20/bin/linux/$TARGETARCH/scm || { echo "Failed to download scm"; exit 1; } \
  && mkdir -m 777 -p client-tools/kubelogin/v0.2.19 \
  && curl -f -s -L -o client-tools/kubelogin/v0.2.19/kubelogin https://app.harness.io/public/shared/tools/kubelogin/release/v0.2.19/bin/linux/$TARGETARCH/kubelogin || { echo "Failed to download kubelogin"; exit 1; } \
  && mkdir -m 777 -p client-tools/harness-credentials-plugin/v0.1.5 \
  && curl -f -s -L -o client-tools/harness-credentials-plugin/v0.1.5/harness-credentials-plugin https://app.harness.io/public/shared/tools/harness-credentials-plugin/release/v0.1.5/bin/linux/$TARGETARCH/harness-credentials-plugin || { echo "Failed to download harness-credentials-plugin"; exit 1; } \
  && curl -f -s -L -o $JAVA_HOME/bin/jattach https://app.harness.io/public/shared/tools/jattach/release/v2.2/bin/linux/$TARGETARCH/jattach || { echo "Failed to download jattach"; exit 1; } \
  && chmod +x $JAVA_HOME/bin/jattach \
  && mkdir -m 777 -p client-tools/hcli/v0.32 \
  && curl -f -s -L -o client-tools/hcli/v0.32/hcli https://app.harness.io/storage/harness-download/harness-ti/hcli/v0.32/hcli-linux-$TARGETARCH \
  && mkdir -m 777 -p client-tools/task-runner/3.10.1 \
  && curl -f -s -L -o client-tools/task-runner/3.10.1/task-runner https://app.harness.io/public/shared/delegates/3.10.1/delegate-linux-$TARGETARCH || { echo "Failed to download task-runner"; exit 1; } \
  && mkdir -m 777 -p client-tools/credential-broker/v0.0.6 \
  && curl -f -s -L -o client-tools/credential-broker/v0.0.6/credential-broker https://app.harness.io/public/shared/tools/credential-broker/release/v0.0.6/bin/linux/$TARGETARCH/credential-broker || { echo "Failed to download credential-broker"; exit 1; } \
  && chmod -R 775 /opt/harness-delegate \
  && chgrp -R 0 /opt/harness-delegate \
  && chown -R 1001 /opt/harness-delegate \
  && chown -R 1001 $JAVA_HOME/lib/security/cacerts

ENV PATH="$JAVA_HOME/bin/jattach:${PATH}"
ENV PATH=/opt/harness-delegate/client-tools/kubectl/v1.36.2/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/go-template/v0.4.16/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/chartmuseum/v0.16.6/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/helm/v3.21.4/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/helm/v4.2.3/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/harness-helm-post-renderer/v0.2.5/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/oc/v4.22.16/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/kubelogin/v0.2.19/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/harness-credentials-plugin/v0.1.5/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/hcli/v0.32/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/task-runner/3.10.1/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/scm/17e330b20/:$PATH
ENV PATH=/opt/harness-delegate/client-tools/credential-broker/v0.0.6/:$PATH

# Run the download-bc.sh script during build time
RUN /opt/harness-delegate/download-bc.sh

COPY --from=delegate-jar-downloader /downloads/delegate.jar /opt/harness-delegate/delegate.jar

USER 1001

HEALTHCHECK --interval=10s --timeout=1s --start-period=10s --retries=3 CMD curl --fail http://localhost:${DELEGATE_HTTP_PORT:-3460}/api/health
ENTRYPOINT ["./setup-bc.sh"]
CMD [ "./start.sh" ]
