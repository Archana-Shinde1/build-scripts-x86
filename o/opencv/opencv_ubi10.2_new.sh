
PACKAGE_NAME="opencv-python-headless"
PACKAGE_VERSION=${1:-94}
BUILD_TYPE=${2:-cpu}     # cpu | cuda
PACKAGE_URL="https://github.com/opencv/opencv-python"
CURRENT_DIR=$(pwd)

# Output directory for generated artifacts
OUTPUT_DIR="${CURRENT_DIR}/output"
mkdir -p "${OUTPUT_DIR}"

# Install system-level build dependencies
yum install -y git make cmake wget python3.14 python3.14-devel \
    python3.14-pip pkgconfig gcc gcc-c++ gcc-gfortran graphviz gcc-toolset-15

export PATH=/opt/rh/gcc-toolset-15/root/usr/bin:$PATH
export LD_LIBRARY_PATH=/opt/rh/gcc-toolset-15/root/usr/lib64:$LD_LIBRARY_PATH

export CC=gcc
export CXX=g++
export CMAKE_C_COMPILER=gcc
export CMAKE_CXX_COMPILER=g++

# Install Python build dependencies
python3.14 -m pip install \
    nvidia-cudnn-cu12==9.5.1.17 \
    numpy==2.5.0 \
    protobuf==6.33.6 \
    scikit-build \
    setuptools \
    cmake==3.* \
    ninja \
    cython \
    build \
    wheel

# Install locally built protobuf wheel
python3.14 -m pip install \
    ./libprotobuf-33.6+ibmpyeco-py3-none-linux_x86_64.whl \
    --force-reinstall

echo "Python site-packages:"
python3.14 -c "import site; print('\n'.join(site.getsitepackages()))"

echo "libprotobuf location:"
python3.14 -c "import libprotobuf; print(libprotobuf.__path__)" || true


echo "Building CV......."

# Clone source
#rm -rf opencv-python

git clone "${PACKAGE_URL}" -b "${PACKAGE_VERSION}" opencv-python

cd opencv-python

WORK_DIR=$(pwd)

# Initialize submodules
git submodule update --init --recursive

# Package name
sed -i "s/^[[:space:]]*name=package_name/name=\"${PACKAGE_NAME}\"/" setup.py

# ----------------------------------------------------------------------
# Build configuration
# ----------------------------------------------------------------------

# Protobuf installed by our libprotobuf wheel
#export PROTOBUF_PREFIX="${SITE_PACKAGE_PATH:-/usr/local/lib/python3.14/site-packages/libprotobuf}"
#export PROTOBUF_LIB="${PROTOBUF_PREFIX}/lib64/libprotobuf.so"
#export PROTOBUF_INCLUDE="${PROTOBUF_PREFIX}/include"
#export CMAKE_PREFIX_PATH="${PROTOBUF_PREFIX}:/usr/local"
#export LD_LIBRARY_PATH="${PROTOBUF_PREFIX}/lib64:/usr/local/lib64:${LD_LIBRARY_PATH}"
export PROTOBUF_PREFIX="/usr/local/lib/python3.14/site-packages/libprotobuf"

export PROTOBUF_LIB="${PROTOBUF_PREFIX}/lib64/libprotobuf.so"
export PROTOBUF_INCLUDE="${PROTOBUF_PREFIX}/include"

export CMAKE_PREFIX_PATH="${PROTOBUF_PREFIX}"
export LD_LIBRARY_PATH="${PROTOBUF_PREFIX}/lib64:/usr/local/lib64:${LD_LIBRARY_PATH}"
#export PROTOBUF_PREFIX="/usr/local"
#export PROTOBUF_LIB="/usr/local/lib/libprotobuf.so"
#export PROTOBUF_INCLUDE="/usr/local/include"

#export CMAKE_PREFIX_PATH="/usr/local"
#export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}"


test -f "${PROTOBUF_LIB}" || {
    echo "ERROR: Protobuf shared library not found: ${PROTOBUF_LIB}"
    exit 1
}

test -d "${PROTOBUF_INCLUDE}" || {
    echo "ERROR: Protobuf headers not found: ${PROTOBUF_INCLUDE}"
    exit 1
}

ls -l "${PROTOBUF_LIB}"

# If libprotobuf wheel is installed system-wide, locate it
#if [[ ! -d "${PROTOBUF_PREFIX}" ]]; then
#    PROTOBUF_PREFIX="/usr/local/lib/python3.14/site-packages/libprotobuf"
#fi

# CUDA architectures
cuda_levels="6.0,7.0,7.5,8.0,8.6,9.0"

CMAKE_CUDA_ARGS=""

if [[ "${BUILD_TYPE}" == "cuda" ]]; then

    # CUDA_HOME should normally already be set.
    if [[ -z "${CUDA_HOME}" ]]; then
        export CUDA_HOME="/usr/local/cuda"
    fi

    # Create unversioned cuDNN symlink if required
    if [[ -f "${SITE_PACKAGE_PATH}/nvidia/cudnn/lib/libcudnn.so.9" ]] && \
       [[ ! -e "${SITE_PACKAGE_PATH}/nvidia/cudnn/lib/libcudnn.so" ]]; then
        ln -s libcudnn.so.9 \
            "${SITE_PACKAGE_PATH}/nvidia/cudnn/lib/libcudnn.so"
    fi

    CMAKE_CUDA_ARGS="
        -DWITH_CUDA=1
        -DWITH_CUBLAS=1
        -DWITH_NVCUVID=0
        -DWITH_NVCUVENC=0
        -DCUDNN_LIBRARY=${SITE_PACKAGE_PATH}/nvidia/cudnn/lib/libcudnn.so
        -DCUDNN_INCLUDE_DIR=${SITE_PACKAGE_PATH}/nvidia/cudnn/include
        -DCUDA_cupti_LIBRARY=${CUDA_HOME}/lib64/libcupti.so
        -DCUDA_SDK_ROOT_DIR=${CUDA_HOME}
        -DENABLE_FAST_MATH=1
        -DCUDA_FAST_MATH=1
        -DCUDA_ARCH_BIN=${cuda_levels//,/;}
    "
fi

# ----------------------------------------------------------------------
# CMake configuration
# ----------------------------------------------------------------------

export CMAKE_ARGS="
    -DCMAKE_BUILD_TYPE=Release
    ${CMAKE_CUDA_ARGS}

    -DCMAKE_PREFIX_PATH=/usr/local

    -DWITH_EIGEN=1

    -DBUILD_TESTS=0
    -DBUILD_DOCS=0
    -DBUILD_PERF_TESTS=0

    -DBUILD_ZLIB=0
    -DBUILD_TIFF=0
    -DBUILD_PNG=0
    -DBUILD_OPENEXR=1
    -DBUILD_JASPER=0
    -DBUILD_JPEG=0

    -DWITH_ITT=1
    -DWITH_V4L=1

    -DWITH_OPENCL=0
    -DWITH_OPENCLAMDFFT=0
    -DWITH_OPENCLAMDBLAS=0
    -DWITH_OPENCL_D3D11_NV=0

    -DWITH_1394=0
    -DWITH_CARBON=0
    -DWITH_OPENNI=0

    -DWITH_FFMPEG=0
    -DHAVE_FFMPEG=0

    -DWITH_JASPER=0
    -DWITH_VA=0
    -DWITH_VA_INTEL=0
    -DWITH_GSTREAMER=0
    -DWITH_MATLAB=0
    -DWITH_TESSERACT=0
    -DWITH_VTK=0
    -DWITH_GTK=0
    -DWITH_QT=0
    -DWITH_GPHOTO2=0

    -DINSTALL_C_EXAMPLES=0

    -DProtobuf_ROOT=/usr/local
    -DProtobuf_INCLUDE_DIR=/usr/local/include
    -DProtobuf_LIBRARY=/usr/local/lib/libprotobuf.so
    -DProtobuf_LIBRARIES=/usr/local/lib/libprotobuf.so

    -DBUILD_PROTOBUF=OFF
    -DBUILD_LIBPROTOBUF_FROM_SOURCES=OFF
    -DPROTOBUF_UPDATE_FILES=ON


    -DWITH_LAPACK=0
    -DHAVE_LAPACK=0
"

echo "============================================================"
echo "Package       : ${PACKAGE_NAME}"
echo "Version       : ${PACKAGE_VERSION}"
echo "Build type    : ${BUILD_TYPE}"
echo "Python        : 3.14"
echo "Protobuf      : ${PROTOBUF_PREFIX}"
echo "Output        : ${OUTPUT_DIR}"
echo "CMAKE_ARGS    : ${CMAKE_ARGS}"
echo "============================================================"

# ----------------------------------------------------------------------
# Build wheel
# ----------------------------------------------------------------------

python3.14 setup.py bdist_wheel --dist-dir "${OUTPUT_DIR}"

echo "============================================================"
echo "${PACKAGE_NAME} wheel build completed"
echo "============================================================"

ls -lh "${OUTPUT_DIR}"

