FROM linuxserver/code-server

# install nginx 
ENV OS_LOCALE="en_US.UTF-8" \
	DEBIAN_FRONTEND=noninteractive
    ENV LANG=${OS_LOCALE} \
	LANGUAGE=en_US:en \
	LC_ALL=${OS_LOCALE}

RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE} \
	&& BUILD_DEPS='wget gnupg' \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \
	&& apt-get install software-properties-common -y \
	&& wget -O - http://nginx.org/keys/nginx_signing.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=noninteractive apt-key add - \
	&& echo "deb http://nginx.org/packages/mainline/ubuntu/ bionic nginx" | tee -a /etc/apt/sources.list \
	&& echo "deb-src http://nginx.org/packages/mainline/ubuntu/ bionic nginx" | tee -a /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install -y nginx \
	# Cleaning
	&& apt-get purge -y --auto-remove $BUILD_DEPS \
	&& apt-get autoremove -y && apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	# Forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
#install golang and client-go
    # Next few lines are needed to install Octant
    && add-apt-repository ppa:longsleep/golang-backports \
	&& apt-get install -y  golang-go \
	&&  GOPATH="/go" GO111MODULE=on go get k8s.io/client-go@latest \
# TOOOOOLS
    &&  curl -L https://k14s.io/install.sh | bash   \
    && curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
    && chmod 700 get_helm.sh  \
    && ./get_helm.sh \
# TMC
    && curl -L -o /usr/local/bin/tmc $(curl -s https://tanzupaorg.tmc.cloud.vmware.com/v1alpha/system/binaries | jq -r 'getpath(["versions",.latestVersion]).linuxX64') && \
  chmod 755 /usr/local/bin/tmc \
# Policy Tools
    && curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 \
    && chmod 755 /usr/local/bin/opa \
# Velero
    && VELERO_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r '.assets[] | select ( .name | contains("linux-amd64") ) .browser_download_url') && \
  curl -fL --output /tmp/velero.tar.gz ${VELERO_DOWNLOAD_URL} && \
  tar -xzf /tmp/velero.tar.gz -C /usr/local/bin --strip-components=1 --wildcards velero-*-linux-amd64/velero && \
  rm /tmp/velero.tar.gz \
# TAC
 && curl -fL --output /tmp/tac.tar.gz https://downloads.bitnami.com/tac/tac-cli_beta-e936104-linux_amd64.tar.gz && \
  tar -xzf /tmp/tac.tar.gz -C /usr/local/bin tac && \
  rm /tmp/tac.tar.gz \
# TBS
# TODO :  Change the logic to identify the latest anbd download  or move to pivnet
 && curl -L -o /usr/local/bin/kp  https://github.com/vmware-tanzu/kpack-cli/releases/download/v0.1.3/kp-linux-0.1.3  && \
  chmod 755 /usr/local/bin/kp \
# COPY kp-linux-0.1.1 /usr/local/bin/kp
#  && chmod 755 /usr/local/bin/kp \
 && curl -sSL "https://github.com/concourse/concourse/releases/download/v6.7.1/fly-6.7.1-linux-amd64.tgz" |sudo tar -C /usr/local/bin/ --no-same-owner -xzv fly


#conftest
COPY --from=instrumenta/conftest /conftest /usr/local/bin/conftest
# Kubectl ,  get it
COPY --from=bitnami/kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
# YQ & JQ
COPY --from=mikefarah/yq /usr/bin/yq /usr/local/bin/yq
COPY --from=stedolan/jq /usr/local/bin/jq /usr/local/bin/jq
# Docker CLI
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker

# COPY ./docker-nginx/configs/nginx.conf /etc/nginx/nginx.conf
WORKDIR /var/www
CMD ["nginx", "-g", "daemon off;"]


EXPOSE 8443
EXPOSE 80