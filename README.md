# Introduction
Tensorflow 1.12.0 build inside a Docker container with CUDA 10.0, based on Ubuntu 18.04 for NVidia Xavier AGX (P2888). Used to build `libensorflow_cc.so` (without`tensorflow_framework.so` because the build is monolithic i.e. static). The Python wheel is built also.

## How to use

### Find out which CUDA Capabilities you need
To find out which capabilities are for you check [Wikipedia's CUDA article](https://en.wikipedia.org/wiki/CUDA). Then edit `.tf_configure.bazelrc-1.12.0` and set `TF_CUDA_COMPUTE_CAPABILITIES` to whatever suits you.
For Xavier P2888 the capability is 7.2

### Tweaking the Build
To change different aspects of the build, please change them in `.tf_configure.bazelrc-1.12.0`. If you dont' want to build with TensorRT check the Dockerfile and comment the appropriate portion of code. TensorRT is installed by default for CUDA 10.0 in version 5.1.6. See the Dockerfile for the installation of the dev and the runtime deb packages.

### Building

## CAUTION
The build won't run without supplying additional files. You need to copy /usr/lib/aarch64-linux-gnu/tegra to the current directory as tegra
```
cp -a /usr/lib/aarch64-linux-gnu/tegra .
```

## More
Tensorflow 1.12.0 is built with Bazel 0.15.0. Just run `make build`. This will build a container with the tag `cuda-CX.CY-tensorflow-TX.TY:cuda-caps-X.Y`. `CX.CY` is the CUDA version and `TX.TY` is the Tensorflow version. The official documentation lists Bazel 0.15.0 as tested for TF 1.10.0, 1.10.1, 1.11.0 and 1.12.0. For TF 1.13.1 they list Bazel 0.19.2 .

### Build times
On Xavier AGX it takes 6-7 hours to complete the whole build.

### Extracting the libraries
To get the compiled libraries, just run `make extract-libraries`. libtensorflow_cc.so and libtensorflow_framework.so (in case  when --config=monolithic is NOT used) will be copied into newly created directory called `shared-cuda-caps-X.Y` . If you build with TensorRT suppor also `_trt_engine_op.so` will be in the shared directory. By default also the wheel package for Python is built. It will also be copied to the shared directory.
