FROM nvcr.io/nvidia/l4t-base:r32.2.1

RUN sed -i "s/archive.ubuntu.com/bg.archive.ubuntu.com/" /etc/apt/sources.list
RUN \   
        apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                libopencv-dev \
                libtinyxml2-6 \
                libtinyxml2-dev \
                libgstreamer1.0-0 \
                libgstreamer1.0-dev \
                libeigen3-dev \
                libc-bin \
                python3-dev \
                python3-pip \
                openjdk-8-jdk-headless \
                curl \
                wget \
                python \
                unzip \
                bash-completion \
                joe less \
                libhdf5-dev \
                python3-ncclient libvncclient1 \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

RUN mkdir /work
WORKDIR /work

ARG JETPACK_BASE_URL=https://developer.download.nvidia.com/devzone/devcenter/mobile/jetpack_l4t/JETPACK_422_b21
ARG XAVIER_PRODUCT_CODE=P2888

RUN wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | sudo apt-key add 

RUN wget $JETPACK_BASE_URL/cuda-repo-l4t-10-0-local-10.0.326_1.0-1_arm64.deb && \
    wget $JETPACK_BASE_URL/$XAVIER_PRODUCT_CODE/tensorrt_5.1.6.1-1+cuda10.0_arm64.deb && \
    wget $JETPACK_BASE_URL/$XAVIER_PRODUCT_CODE/libnvinfer5_5.1.6-1+cuda10.0_arm64.deb && \
    wget $JETPACK_BASE_URL/$XAVIER_PRODUCT_CODE/libnvinfer-dev_5.1.6-1+cuda10.0_arm64.deb && \
    wget $JETPACK_BASE_URL/$XAVIER_PRODUCT_CODE/libcudnn7_7.5.0.56-1+cuda10.0_arm64.deb && \
    wget $JETPACK_BASE_URL/$XAVIER_PRODUCT_CODE/libcudnn7-dev_7.5.0.56-1+cuda10.0_arm64.deb && \
    dpkg -i libcudnn7*.deb && \
    dpkg -i cuda-repo-l4t-10-0-local-10.0.326_1.0-1_arm64.deb && \
    apt update && \
    apt install -y cuda-command-line-tools-10-0 \
	cuda-compiler-10-0 \
	cuda-core-10-0 \
	cuda-cublas-10-0 \
	cuda-cublas-dev-10-0 \
	cuda-cudart-10-0 \
	cuda-cudart-dev-10-0 \
	cuda-cufft-10-0 \
	cuda-cufft-dev-10-0 \
	cuda-cuobjdump-10-0 \
	cuda-cupti-10-0 \
	cuda-curand-10-0 \
	cuda-curand-dev-10-0 \
	cuda-cusolver-10-0 \
	cuda-cusolver-dev-10-0 \
	cuda-cusparse-10-0 \
	cuda-cusparse-dev-10-0 \
	cuda-driver-dev-10-0 \
	cuda-gpu-library-advisor-10-0 \
	cuda-libraries-10-0 \
	cuda-libraries-dev-10-0 \
	cuda-license-10-0 \
	cuda-memcheck-10-0 \
	cuda-minimal-build-10-0 \
	cuda-misc-headers-10-0 \
	cuda-npp-10-0 \
	cuda-npp-dev-10-0 \
	cuda-nvgraph-10-0 \
	cuda-nvgraph-dev-10-0 \
	cuda-nvml-dev-10-0 \
	cuda-nvprof-10-0 \
	cuda-nvprune-10-0 \
	cuda-nvrtc-10-0 \
	cuda-nvrtc-dev-10-0 \
	cuda-nvtx-10-0 \
	cuda-toolkit-10-0 \
	cuda-tools-10-0 \
     && apt-get clean \
     && rm -rf /var/lib/apt/lists/* \
     && dpkg -i libnvinfer*.deb \
     && rm *.deb

# The following addition to LD path is needed or the bazel build will break with errors due to undefined references
# See https://github.com/tensorflow/tensorflow/issues/13243
# If you don't want to do this, thenn just build with `bazel build --config=opt --config=monolithic //tensorflow:libtensorflow_cc.so`
# In case of monolithic build there is only one build artefact - libtensorflow_cc.so and there is no libtensorflow_framework.so
RUN echo "/usr/local/cuda/targets/x86_64-linux/lib/stubs" >> /etc/ld.so.conf.d/cuda-10-0.conf && ldconfig

RUN pip3 install setuptools
RUN pip3 install wheel
RUN pip3 install numpy
RUN pip3 install pandas
RUN pip3 install keras_applications==1.0.8 --no-deps
RUN pip3 install keras_preprocessing==1.0.9 --no-deps
RUN pip3 install h5py==2.8.0
RUN pip3 install virtualenv

ADD tegra /usr/lib/aarch64-linux-gnu/

ENV TMP /tmp

ARG BAZEL_VERSION=0.15.0
ADD bazel-$BAZEL_VERSION-* /work/
RUN cat bazel-$BAZEL_VERSION-part-aa bazel-$BAZEL_VERSION-part-ab > /usr/bin/bazel && chmod 555 /usr/bin/bazel

ARG TENSORFLOW_VERSION=1.12.0
RUN wget https://github.com/tensorflow/tensorflow/archive/v$TENSORFLOW_VERSION.tar.gz -O tensorflow.tar.gz \
        && tar zxvf tensorflow.tar.gz \
        && rm tensorflow.tar.gz \
        && mv tensorflow-$TENSORFLOW_VERSION tensorflow


COPY .bazelrc-$TENSORFLOW_VERSION /work/tensorflow/.bazelrc
COPY .tf_configure.bazelrc-$TENSORFLOW_VERSION /work/tensorflow/.tf_configure.bazelrc

WORKDIR /work/tensorflow

COPY BUILD.patch-$TENSORFLOW_VERSION /work/tensorflow/BUILD.patch
RUN patch -p0 < BUILD.patch

# otherwise one symbol from stream_executor won't be visible
# see https://github.com/tensorflow/tensorflow/issues/19840
# The code does not exist up to 1.12.0 incl. In 1.13 it is there and the patch will fail
COPY tf_version_script.lds.patch /work/tensorflow
RUN patch -p0 tf_version_script.lds.patch


ARG BUILD_TYPE="--config=opt --config=monolithic"
RUN bazel build $BUILD_TYPE //tensorflow/stream_executor/...
RUN bazel build $BUILD_TYPE //tensorflow:libtensorflow_cc.so //tensorflow:libtensorflow_framework.so 

RUN bazel build $BUILD_TYPE  \
		//tensorflow/contrib/rnn:all_ops \
		//tensorflow/contrib/rnn:all_kernels

RUN bazel build $BUILD_TYPE \
		//tensorflow/contrib/tensorrt:trt_engine_op_loader \
		//tensorflow/contrib/tensorrt:python/ops/_trt_engine_op.so


RUN bazel build $BUILD_TYPE //tensorflow/tools/pip_package:build_pip_package

RUN virtualenv --system-site-packages -p python3 ./venv
RUN bash -c "source venv/bin/activate && ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg"

# This is for 1.14.0 and newer
# The headers are then in bazel-genfiles/tensorflow/include
#RUN  bazel build $BUILD_TYPE //tensorflow:install_headers
