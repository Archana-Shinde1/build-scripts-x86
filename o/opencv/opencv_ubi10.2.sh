PACKAGE_NAME="opencv-python-headless"
PACKAGE_VERSION=${1:-94}
BUILD_TYPE=${2:-cpu}     # cpu | cuda
PACKAGE_URL="https://github.com/opencv/opencv-python"
CURRENT_DIR=$(pwd)
#PACKAGE_DIR=opencv-python


# Output directory for generated artifacts
#OUTPUT_FOLDER="$(pwd)/output"
#SCRIPT_DIR=$(pwd)

# Install system-level build dependencies required for XGBoost
yum install -y git make cmake wget python3.14 python3.14-devel python3.14-pip pkgconfig gcc gcc-c++ gcc-gfortran graphviz gcc-toolset-15
export PATH=/opt/rh/gcc-toolset-15/root/usr/bin:$PATH

# Only if need GCC Toolset 15 runtime libraries:
export LD_LIBRARY_PATH=/opt/rh/gcc-toolset-15/root/usr/lib64:$LD_LIBRARY_PATH

export CC=gcc
export CXX=g++
export CMAKE_C_COMPILER=gcc
export CMAKE_CXX_COMPILER=g++

# Install Python build and test dependencies
pip install nvidia-cudnn-cu12==9.5.1.17 numpy==2.5.0 protobuf==4.25.3 scikit-build setuptools cmake==3.* ninja cython build wheel  
pip install ./libprotobuf-33.6-py3-none-linux_x86_64.whl

# ============================================================ # Verify libprotobuf installation # ============================================================ echo "libprotobuf installation:" "$PYTHON" -m pip show libprotobuf || true echo echo "Building CV......."



 echo "Building CV......."
# git clone $PACKAGE_URL -b $PACKAGE_VERSION
 
 #Build opencv
 echo "$PACKAGE build starts!!"
 cd opencv-python
 WORK_DIR=$(pwd)
 git submodule update --init --recursive



 
python3.14 -m build --wheel --no-isolation --outdir $CURRENT_DIR

