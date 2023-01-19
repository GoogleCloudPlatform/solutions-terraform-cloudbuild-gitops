FROM 208676797693.dkr.ecr.eu-west-1.amazonaws.com/ubuntu:18.04

ENV BAZEL_INSTALLER https://github.com/bazelbuild/bazel/releases/download/0.28.1/bazel-0.28.1-installer-linux-x86_64.sh
ENV BAZEL_TMP /tmp/bazel-installer.sh
ENV KUBECTL_URL https://storage.googleapis.com/kubernetes-release/release/v1.12.6/bin/linux/amd64/kubectl
ENV AWS_IAM_AUTHENTICATOR_URL https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
ENV LC_ALL en_US.UTF-8

RUN apt-get update -y && \
    apt-get install -y \
        curl \
        g++ \
        git \
        language-pack-en-base \
        openssh-client \
        pkg-config \
        python \
        python-pip \
        software-properties-common \
        unzip \
        wget \
        zip \
        zlib1g-dev && \
    dpkg-reconfigure locales && \
    locale-gen $LC_ALL && \
    update-locale LANG=$LC_ALL && \
    wget -qO - https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update -y && \
    apt-get install -y docker-ce && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q "$BAZEL_INSTALLER" -O "$BAZEL_TMP" && \
    chmod +x "$BAZEL_TMP" && \
    "$BAZEL_TMP" && \
    rm -f "$BAZEL_TMP" && \
    wget -q "$KUBECTL_URL" -O /usr/local/bin/kubectl && \
    chmod 755 /usr/local/bin/kubectl && \
    wget -q "$AWS_IAM_AUTHENTICATOR_URL" -O /usr/local/bin/aws-iam-authenticator && \
    chmod 755 /usr/local/bin/aws-iam-authenticator && \
    pip install -U awscli
