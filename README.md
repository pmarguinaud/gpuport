# IAL GPU Port Build Environment

This directory contains the automation scripts used to create a containerised build environment for **IAL** (ARPEGE & AROME) with support for the **NVIDIA HPC SDK (NVHPC)**, **AMD ROCm** and **Intel oneAPI** toolchains.

The typical workflow is:

1. Build a Singularity container with base development tools.
2. Enter the container and install the required math libraries, compilers, and MPI stacks.
3. Install `fxtran`, the source-to-source transformation tool used by IAL.
4. Build IAL for the desired target architecture.

---

## Prerequisites

* Linux host with **Singularity/Apptainer** installed (`singularity build --fakeroot` is used).
* Sufficient disk space under `$HOME/gpuport` (or wherever this repository is checked out).
* Network access for downloading NVIDIA HPC SDK, ROCm, Intel oneAPI, Intel MKL, HDF5, NetCDF, and OpenMPI sources.

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

After installation, the script loads the `nvhpc/26.5` module automatically. The NVHPC modulefiles are linked into `install/modulefiles`, see [Compiler modules](#compiler-modules).

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
* Generates the modulefile `install/modulefiles/rocm/23.2.1`, see [Compiler modules](#compiler-modules)

### 5b. Build UCX

UCX provides the native InfiniBand transport used by OpenMPI, and must be built
**before** `rocm.sh`, which configures OpenMPI against it.

```
./scripts/ucx.sh [ROCM_VERSION]
```

* Default ROCm version tag: `2321`
* Installs UCX 1.17.0 to: `install/rocm/2321/ucx`

### 6. Install the Intel oneAPI toolchain

This installs the Intel oneAPI toolkit (C, C++ and Fortran compilers) and builds the HDF5 / NetCDF4-Fortran dependency chain against it.

```bash
./scripts/intel.sh [URL]
```

* Default: downloads the **Intel oneAPI toolkit 2026.1.1** offline installer (`intel-oneapi-toolkit-2026.1.1.33_offline.sh`).
* Installs to: `install/intel/oneapi/` (compilers under `install/intel/oneapi/compiler/2026.1`; the toolkit also provides MKL and Intel MPI)
* Sets `CC=icx`, `CXX=icpx`, `FC=ifx`
* Builds HDF5 1.14.6 under `install/intel/2026.1/hdf5/1.14.3`
* Builds NetCDF-C 4.9.3 and NetCDF-Fortran 4.6.2 under `install/intel/2026.1/netcdf4/4.9.2`
* Generates the modulefile `install/modulefiles/intel/2026.1`, see [Compiler modules](#compiler-modules)

The Intel compilers do not record the location of their runtime libraries (`libimf`, `libsvml`, `libifcoremt`, ...), so the libraries are linked with an rpath to `install/intel/oneapi/compiler/<version>/lib`. Executables built with `icx`/`ifx` need the same rpath, or the Intel environment loaded (`source install/intel/oneapi/compiler/<version>/env/vars.sh`) at run time.

### 7. Install fxtran

`fxtran` is the Fortran parser and source-transformation utility required by the IAL `fxtran` architecture files.

```bash
./scripts/fxtran.sh
```

This clones `https://github.com/pmarguinaud/fxtran`, builds the C library and the Perl bindings, and installs them under `install/fxtran`. It also installs the Perl dependency `XML::XPath::Parser` via `cpanm`.

### 8. Build IAL

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

## Compiler modules

`nvhpc.sh`, `rocm.sh` and `intel.sh` register the compilers they install in `install/modulefiles`, and `scripts/bashrc` adds this directory to `MODULEPATH` when entering the container with `singularity-shell.sh`:

```bash
module avail
module load rocm/24.3.0   # amdflang, amdclang, amdclang++, OpenMPI
module load nvhpc/26.9    # nvfortran, nvc, nvc++, OpenMPI
module load intel/2026.1  # ifx, icx, icpx, Intel MPI, MKL
```

The `rocm`, `nvhpc` and `intel` modules conflict with each other: unload one before loading another. They do not set up HDF5 or NetCDF. Modules are not needed for the IAL builds, which purge them and set up their own environment.

For an existing installation, running `nvhpc.sh`, `rocm.sh` or `intel.sh` again creates the modules without rebuilding anything.

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

### `ucx.sh`
Downloads and builds UCX 1.17.0 under `install/rocm/<version>/ucx`, with multi-threading
and the InfiniBand (verbs / mlx5) transports enabled. Must be run before `rocm.sh`.

### `intel.sh`
Downloads and silently installs the Intel oneAPI toolkit, then compiles and installs HDF5 and NetCDF-C/Fortran with the Intel compilers (`icx` / `icpx` / `ifx`), adding an rpath to the Intel runtime libraries. The installation is skipped if `ifx` is already present under `install/intel/oneapi/compiler/<version>`. Libraries are placed under `install/intel/<version>/`.

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
