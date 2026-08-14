#!/bin/bash -e
# -----------------------------------------------------------------------------
#
# Package          : tensorflow
# Version          : v2.21.0
# Source repo      : https://github.com/tensorflow/tensorflow
# Tested on        : UBI:10.1
# Language         : Python
# Travis-Check     : True
# Script License   : Apache License, Version 2 or later
# Maintainer       : Vibhav Dhaimode <Vibhav.Dhaimode4@ibm.com>
#
# Disclaimer       : This script has been tested in root mode on given
# ==========         platform using the mentioned version of the package.
#                    It may not work as expected with newer versions of the
#                    package and/or distribution. In such case, please
#                    contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------

set -xe

PACKAGE_DIR=hdf5
PACKAGE_VERSION=${1:-hdf5_2_1_0}
PACKAGE_URL=https://github.com/HDFGroup/hdf5

# install core dependencies
yum install -y python3.12 python3.12-pip python3.12-devel git wget make cmake gcc gcc-c++ zlib zlib-devel
WORK_DIR=$(pwd)
LOCAL_DIR=local
CPU_COUNT=`python3.12 -c 'import multiprocessing ; print (multiprocessing.cpu_count())'`

# clone source repository
if [ ! -d "${PACKAGE_NAME}" ]; then
    git clone "${PACKAGE_URL}" "${PACKAGE_NAME}"
fi
cd $PACKAGE_DIR
git checkout $PACKAGE_VERSION
git submodule update --init

# Install ninja fo building hdf5
python3.12 -m pip install setuptools ninja==1.13.0
# HDF5 2.1.0+ uses CMake build system
mkdir -p build
cd build

cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$HDF5_PREFIX \
    -DCMAKE_C_COMPILER=/usr/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
    -DBUILD_SHARED_LIBS=ON \
    -DHDF5_ENABLE_Z_LIB_SUPPORT=ON \
    -DHDF5_BUILD_CPP_LIB=ON \
    -DHDF5_BUILD_FORTRAN=OFF \
    -DHDF5_ENABLE_PARALLEL=OFF \
    -DHDF5_ENABLE_THREADSAFE=ON \
    -DHDF5_ALLOW_UNSUPPORTED=ON \
    -DHDF5_BUILD_HL_LIB=ON \
    -DHDF5_BUILD_TOOLS=ON \
    -DHDF5_BUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF \
    -DHDF5_ENABLE_SZIP_SUPPORT=OFF \
    ..

cmake --build . --parallel $(nproc)
cmake --install .
cd "${WORK_DIR}"

# Copy HDF5 shared libraries into Python package
mkdir -p hdf5/local/hdf5/lib

cp hdf5/build/bin/libhdf5.so  hdf5/local/hdf5/lib/
cp hdf5/build/bin/libhdf5_cpp.so  hdf5/local/hdf5/lib/
cp hdf5/build/bin/libhdf5_hl.so  hdf5/local/hdf5/lib/
cp hdf5/build/bin/libhdf5_hl_cpp.so  hdf5/local/hdf5/lib/
cp hdf5/build/bin/libhdf5_tools.so  hdf5/local/hdf5/lib/

#install pyproject.toml
wget https://raw.githubusercontent.com/i-wheels-cpd/build-scripts/refs/heads/main/h/hdf5/pyproject.toml
sed -i "s/{PACKAGE_VERSION}/${PACKAGE_VERSION}/g" pyproject.toml
sed -i \
's/version = "hdf5[.*-]\([0-9]*\)[.*-]\([0-9]*\)[._-]\([0-9]*\)[._-]*\([0-9]*\)"/version = "\1.\2.\3\4"/' \
pyproject.toml

# Build HDF5 Python wheel
python3.12 -m pip wheel \
    --wheel-dir="${WORK_DIR}" \
    -v . \
    --no-build-isolation

# Locate the generated wheel
WHEEL=$(find "${WORK_DIR}" -maxdepth 1 -type f -name "hdf5-*.whl" -print -quit)

if [ -z "${WHEEL}" ]; then
    echo "ERROR: HDF5 wheel was not created"
    echo "Searching current directory:"
    find . -maxdepth 3 -type f -name "*.whl" -print
    exit 1
fi

echo "Built wheel: ${WHEEL}"

# Install the generated wheel
if ! python3.12 -m pip install "${WHEEL}" --no-deps --force-reinstall; then
    echo "------------------${PACKAGE}:Install_fails-------------------------------------"
    echo "${PACKAGE} | ${PACKAGE_URL} | ${PACKAGE_VERSION} | GitHub | Fail | Install_Fails"
    exit 1
fi

# Determine the installed package location
SITE_PACKAGES=$(python3.12 -m pip show hdf5 | awk -F': ' '/^Location:/ {print $2}')

if [ -z "${SITE_PACKAGES}" ]; then
    echo "ERROR: HDF5 package not found"
    exit 1
fi

echo "HDF5 installed at: ${SITE_PACKAGES}"

# Verify that all required HDF5 shared libraries are installed
hdf5_libs=("hdf5" "hdf5_cpp" "hdf5_hl" "hdf5_hl_cpp")

for library in "${hdf5_libs[@]}"; do
    filename="${SITE_PACKAGES}/hdf5/lib/lib${library}.so"

    if [ ! -f "${filename}" ]; then
        echo "ERROR: ${filename} not found"
        exit 1
    else
        echo "${filename} found"
    fi
done

echo "All HDF5 libraries found"
