# IAL GPU Port Build Environment

This directory contains the automation scripts used to create a containerised build environment for **IAL** (ARPEGE & AROME) with support for both the **NVIDIA HPC SDK (NVHPC)** and **AMD ROCm** toolchains.

The typical workflow is:

1. Build a Singularity container with base development tools.
2. Enter the container and install the required math libraries, compilers, and MPI stacks.
3. Install `fxtran`, the source-to-source transformation tool used by IAL.
4. Build IAL for the desired target architecture.

---

## Prerequisites

* Linux host with **Singularity/Apptainer** installed (`singularity build --fakeroot` is used).
* Sufficient disk space under `$HOME/gpuport` (or wherever this repository is checked out).
* Network access for downloading NVIDIA HPC SDK, ROCm, Intel MKL, HDF5, NetCDF, and OpenMPI sources.

---

## Directory Layout

The scripts assume the following relative layout:

```
$HOME/gpuport/           # this repository
├── scripts/             # build automation (this directory)
├── install/             # installed toolchains & libraries
├── sources/             # downloaded tarballs
├── tmp/                 # temporary build directories
└── .singularity.sif     # the container image

$HOME/gpuport/IAL/       # IAL source code 
└── bundle/
    ├── ial-bundle
    └── arch/fxtran/

$HOME/gpuport/IAL-build/ # IAL bundle & build
└── source/
└── build.<build-type>/
```

---

## Step-by-Step Workflow

### 1. Build the Singularity container

Run the container definition builder. This creates `.singularity.sif` in the repository root.

```bash
./scripts/singularity-make.sh
```

The image is based on **Ubuntu 26.04** and includes compilers (GCC/GFortran), CMake, OpenMPI, Python, Perl modules, Git, debugging tools, and other HPC build dependencies.

### 2. Enter the container shell

Launch an interactive bash session inside the container. Your dotfiles (`.vimrc`, `.ssh`, `.gitconfig`, `.git-credentials`) are bound in read-only where appropriate.

```bash
./scripts/singularity-shell.sh
```

The shell sources `scripts/bashrc`, which sets up the local environment (paths, Perl libraries, aliases).

### 3. Install Intel oneMKL

Intel MKL is required for CPU builds of IAL.

```bash
./scripts/mkl.sh [URL]
```

If no URL is provided, the script downloads **Intel oneMKL 2026.0.0** and installs it under `install/intel/oneapi/mkl/`.

### 4. Install the NVHPC toolchain

This installs the NVIDIA HPC SDK and builds the HDF5 / NetCDF4-Fortran dependency chain against it.

```bash
./scripts/nvhpc.sh [URL]
```

* Default: downloads **NVHPC 26.5** with CUDA 12 multi-target support.
* Installs to: `install/nvidia/hpc_sdk/Linux_x86_64/26.5`
* Builds HDF5 1.14.3 under `install/nvhpc/26.5/hdf5/1.14.3`
* Builds NetCDF-C 4.9.3 and NetCDF-Fortran 4.6.2 under `install/nvhpc/26.5/netcdf4/4.9.2`

After installation, the script loads the `nvhpc/26.5` module automatically.

### 5. Install the ROCm toolchain

This installs the AMD ROCm AFAR compiler and builds OpenMPI, HDF5, and NetCDF against it.

```bash
./scripts/rocm.sh [URL]
```

* Default: downloads **ROCm AFAR 23.2.1** (`therock-afar-23.2.1-gfx94X...`).
* Installs to: `install/rocm/2321/`
* Sets `FC=amdflang`, `CC=amdclang`, `CXX=amdclang++`
* Builds OpenMPI 5.0.7 under `install/rocm/2321/openmpi-5.0.7`
* Builds HDF5 and NetCDF under `install/rocm/2321/hdf5/1.14.3` and `.../netcdf4/4.9.2`

### 6. Install fxtran

`fxtran` is the Fortran parser and source-transformation utility required by the IAL `fxtran` architecture files.

```bash
./scripts/fxtran.sh
```

This clones `https://github.com/pmarguinaud/fxtran`, builds the C library and the Perl bindings, and installs them under `install/fxtran`. It also installs the Perl dependency `XML::XPath::Parser` via `cpanm`.

### 7. Build IAL

#### Create the bundle

Clone IAL into $HOME/gpuport:

```bash
cd $HOME/gpuport
git clone -b aplaromeopenmp3 https://github.com/pmarguinaud/IAL
```

Create a bundle:

```bash
mkdir -p IAL-build
cd IAL-build
../IAL/bundle/ial-bundle create --bundle ../IAL/bundle/bundle.yml
```

With the toolchains installed, you can now build IAL. Two helper scripts are provided for the two primary CPU targets.

#### NVHPC build

```bash
./scripts/ial-nvhpc-cpu1.sh
```

* Build tag: `CPU_O1_NVHPC26.5_CUDA12.9_HPCX2.25.1`
* Uses `IAL/bundle/ial-bundle build` with architecture `IAL/bundle/arch/fxtran/`
* Build type: `FXTRAN_CPU_O1_NVHPC26.5_CUDA12.9_HPCX2.25.1`
* Parallelism: `-j 32`
* Target: `forecast-only`

#### ROCm build

```bash
./scripts/ial-rocm-cpu1.sh
```

* Build tag: `CPU_O1_ROCM2321_OPENMPI5.0.7`
* Uses the same IAL bundle and architecture path
* Build type: `FXTRAN_CPU_O1_ROCM2321_OPENMPI5.0.7`
* Parallelism: `-j 64`
* Target: `forecast-only`

The build artefacts are placed in `build.<tag>/` inside the repository root.

---

## Script Reference

### `singularity-make.sh`
Defines and builds the Ubuntu 26.04 HPC development container (`$prefix/.singularity.sif`). It installs compilers, MPI, Python, Perl modules, debugging and profiling tools, and configures locales for `fr_FR.UTF-8`.

### `singularity-shell.sh`
Launches an interactive bash shell inside the Singularity container. It binds the project directory, `/scratch`, local vim/cpanm caches, SSL certificates, and personal configuration files. The shell is started with `scripts/bashrc` as its run-control file.

### `singularity-exec.sh`
A lightweight wrapper to execute an arbitrary command inside the container without entering an interactive shell.

```bash
./scripts/singularity-exec.sh <command> [args...]
```

### `bashrc`
Environment setup sourced automatically inside the container. It:
* Points `PATH` to the local `fxtran` binaries (`$HOME/gpuport/install/fxtran/bin`).
* Sets `PERL5LIB` for local Perl modules.
* Enables `vi` line-editing mode.
* Provides convenience aliases (`rm` → safe-delete wrapper, `ls` → `ls -N --color=auto`).

### `mkl.sh`
Downloads and silently installs Intel oneMKL. If the requested version is already present under `install/intel/oneapi/mkl/<version>`, the installation is skipped.

### `nvhpc.sh`
Downloads and installs the NVIDIA HPC SDK, then compiles and installs HDF5 and NetCDF-C/Fortran against that toolchain. All components are cached in `sources/` and installed under `install/nvidia/hpc_sdk` and `install/nvhpc/<version>/`.

### `rocm.sh`
Downloads and installs the ROCm AFAR compiler release, then builds OpenMPI, HDF5, and NetCDF-C/Fortran with the AMD LLVM-based compilers (`amdflang` / `amdclang`). Installations are placed under `install/rocm/<version>/`.

### `fxtran.sh`
Clones the `fxtran` repository, compiles the native code and Perl bindings, installs them locally, and pulls in the required `XML::XPath::Parser` CPAN module.

### `ial-nvhpc-cpu1.sh`
Build driver for an IAL **CPU** configuration using the NVHPC 26.5 compiler, CUDA 12.9, and HPCX 2.25.1. It invokes `ial-bundle` with the `fxtran` architecture and a `forecast-only` scope.

### `ial-rocm-cpu1.sh`
Build driver for an IAL **CPU** configuration using ROCm 23.2.1 and OpenMPI 5.0.7. Like the NVHPC script, it uses the `fxtran` architecture and builds the forecast-only bundle.

---

## Notes

* The IAL source tree (`IAL/`) is **not** part of this repository; these scripts assume it has been cloned or linked separately.
* The build scripts reference the architecture directory `IAL/bundle/arch/fxtran/`, so `fxtran` must be installed before building IAL.
* Both IAL build scripts remove `build.<tag>/bin/MASTERODB` before starting to force a relink of the final executable.
