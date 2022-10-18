FROM ubuntu:20.04
SHELL ["/bin/bash", "-c"]

LABEL   maintainer="Carlos Rodriguez Lopez <crodriguezlopez@cloudbees.com>" \
    updated_at=2022-09-28

# Tooling
WORKDIR /root

ENV PATH="${PATH}:/asdf/.asdf/shims:/asdf/.asdf/bin" \
    AWS_VERSION=2.2.33 \
    EKSCTL_VERSION=0.68.0-rc.0 \
    HELM_VERSION=3.5.0 \
    HELMFILE_VERSION=0.143.0 \
    HELMDIFF_VERSION=3.4.2 \
    JAVA_VERSION=adoptopenjdk-8.0.265+1 \
    JQ_VERSION=1.6 \
    YQ_VERSION=3.4.1 \
    K9s_VERSION=0.25.17 \
    KUBECTL_VERSION=1.23.4 \
    VELERO_VERSION=v1.8.0

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git \ 
    unzip \
    # No gpg, https://stackoverflow.com/a/61692849 
    gnupg \
    gpg-agent \
    parallel \ 
    vim \
    wget \
    less \
    ca-certificates \
    openssh-client \
    wget \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git .asdf && \
    echo -e 'source /root/.asdf/asdf.sh' >> .bashrc && \
    echo -e 'source /root/.asdf/asdf.sh' >> .profile

RUN source .profile && \
    asdf plugin add awscli && \
    asdf install awscli $AWS_VERSION && \
    asdf global awscli $AWS_VERSION && \
    asdf plugin add eksctl && \
    asdf install eksctl $EKSCTL_VERSION && \
    asdf global eksctl $EKSCTL_VERSION && \
    asdf plugin add helm && \
    asdf install helm $HELM_VERSION && \
    asdf global helm $HELM_VERSION && \
    asdf plugin add helm-diff && \
    asdf install helm-diff $HELMDIFF_VERSION && \
    asdf global helm-diff $HELMDIFF_VERSION && \
    asdf plugin add helmfile && \
    asdf install helmfile $HELMFILE_VERSION && \
    asdf global helmfile $HELMFILE_VERSION && \
    asdf plugin add java && \
    asdf install java $JAVA_VERSION && \
    asdf global java $JAVA_VERSION && \
    asdf plugin add jq && \
    asdf install jq $JQ_VERSION && \
    asdf global jq $JQ_VERSION && \
    asdf plugin add yq && \
    asdf install yq $YQ_VERSION && \
    asdf global yq $YQ_VERSION && \    
    asdf plugin add k9s && \
    asdf install k9s $K9s_VERSION && \
    asdf global k9s $K9s_VERSION && \
    asdf plugin add kubectl && \
    asdf install kubectl $KUBECTL_VERSION && \
    asdf global kubectl $KUBECTL_VERSION && \
    asdf plugin add velero && \
    asdf install velero $VELERO_VERSION && \
    asdf global velero $VELERO_VERSION

# Place into the mount with the Project Code
WORKDIR /root/demo-scm