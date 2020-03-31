using BinaryBuilder, Pkg

name = "LAMMPS"
builder_version = v"0.2.0"

output = Dict()

requested_version = last(BinaryBuilder.extract_flag!(ARGS, "--version"))
wants_version = vn -> (
    requested_version === nothing || VersionNumber(requested_version) == vn
)

# Downloading the sources and BB tools can take a while when they are not
# cached.  This should help in those instances (e.g. Travis CI)
requested_targets = filter(arg -> !startswith(arg, "--"), ARGS)
wants_target = t -> (isempty(requested_targets) || t in requested_targets)
# Remove collected targets from ARGS as we handle them directly
filter!(arg -> startswith(arg, "--"), ARGS)

# LAMMPS uses an ugly custom date-based versioning scheme, instead of SemVer or
# CalVer, so we map these to the CalVer equivalents.
versions_dict = Dict(
    "3Mar2020" => v"2020.3.3",
    "7Aug2019" => v"2019.8.7",
)
hashes_dict = Dict(
    "3Mar2020" => "a1a2e3e763ef5baecea258732518d75775639db26e60af1634ab385ed89224d1",
    "7Aug2019" => "5380c1689a93d7922e3d65d9c186401d429878bb3cbe9a692580d3470d6a253f",
)

#======================#
#  Common definitions  #
#======================#
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

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = Platform[]
if wants_target("x86_64-linux-gnu")
    push!(platforms, Linux(:x86_64, libc=:glibc))
end
if wants_target("aarch64-linux-gnu")
    push!(platforms, Linux(:aarch64, libc=:glibc))
end
if wants_target("powerpc64le-linux-gnu")
    push!(platforms, Linux(:powerpc64le, libc=:glibc))
end
platforms = expand_cxxstring_abis(platforms)

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

#======================#
#  Build the tarballs  #
#======================#
for tag in keys(versions_dict)
    version = versions_dict[tag]
    if wants_version(version)
        sources = [ArchiveSource(source_url(tag), hashes_dict[tag])]
        output[tag] = build_tarballs(
            ARGS, name, version, sources, script, platforms, products, dependencies
        )
    end
end

#======================#
#  Generate artifacts  #
#======================#
using Pkg.Artifacts

bin_url = "https://github.com/pabloferz/LAMMPSBuilder/releases/download/v$(builder_version)"
artifacts_toml = joinpath(@__DIR__, "Artifacts.toml")

for tag in keys(output)
    src_name = "LAMMPS_$(tag)"

    for platform in keys(output[tag])
        tarball_name, tarball_hash, git_hash, products_info = output[tag][platform]
        download_info = Tuple[(joinpath(bin_url, basename(tarball_name)), tarball_hash)]
        bind_artifact!(
            artifacts_toml, src_name, git_hash;
            platform = platform, download_info = download_info, force = true, lazy = true
        )
    end
end
