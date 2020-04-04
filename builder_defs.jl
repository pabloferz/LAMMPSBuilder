#==============================#
#  Common builder definitions  #
#==============================#
name = "LAMMPS"

# LAMMPS uses an ugly custom date-based versioning scheme, instead of SemVer or
# CalVer, so we map these to the CalVer equivalents.
versions_info = Dict(
    v"2020.3.3" => (
        tag  = "3Mar2020",
        hash = "a1a2e3e763ef5baecea258732518d75775639db26e60af1634ab385ed89224d1",
    ),
    v"2019.8.7" => (
        tag  = "7Aug2019",
        hash = "5380c1689a93d7922e3d65d9c186401d429878bb3cbe9a692580d3470d6a253f",
    ),
)

source_url = tag -> "https://github.com/lammps/lammps/archive/stable_$(tag).tar.gz"

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd lammps-*
mkdir build
cd build

CXX_FLAGS=(-std=c++11)
if [[ "${target}" == *linux* ]]; then
    CXX_FLAGS+=(-lrt)
fi

CMAKE_FLAGS=(
    -DCMAKE_INSTALL_PREFIX=${prefix}
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_FLAGS="${CXX_FLAGS[*]}"
    -DBUILD_LIB=ON
    -DBUILD_SHARED_LIBS=ON
    -DLAMMPS_EXCEPTIONS=ON
    -DPKG_USER-INTEL=OFF
)

cmake ../cmake \
    -C ../cmake/presets/all_on.cmake \
    -C ../cmake/presets/nolib.cmake \
    "${CMAKE_FLAGS[@]}"
make -j${nproc}
make install
"""

# The products that we will ensure are always built
products = [
    LibraryProduct("liblammps", :liblammps),
    ExecutableProduct("lmp", :lammps)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(
        name = "CompilerSupportLibraries_jll",
        uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
    ))
    Dependency(PackageSpec(
        name = "FFMPEG_jll",
        uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
    ))
    Dependency(PackageSpec(
        name = "FFTW_jll",
        uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
    ))
    Dependency(PackageSpec(
        name = "OpenBLAS_jll",
        uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
    ))
    Dependency(PackageSpec(
        name = "OpenMPI_jll",
        uuid = "fe0851c0-eecd-5654-98d4-656369965a5c"
    ))
    Dependency(PackageSpec(
        name = "Zlib_jll",
        uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
    ))
    Dependency(PackageSpec(
        name = "libpng_jll",
        uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
    ))
]
