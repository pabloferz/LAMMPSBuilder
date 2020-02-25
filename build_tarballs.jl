using BinaryBuilder, Pkg

name = "LAMMPS"
tag = v"0.1.0"

output = Dict()

function extract_flag!(ARGS, flag, val = nothing)
    for f in ARGS
        if f == flag || startswith(f, string(flag, "="))
            # Check if it's just `--flag` or if it's `--flag=foo`
            if f != flag
                val = split(f, '=')[2]
            end

            # Drop this value from our ARGS
            filter!(x -> x != f, ARGS)
            return (true, val)
        end
    end
    return (false, val)
end

requested_version = VersionNumber(extract_flag!(ARGS, "--version")[end])
wants_version = ver -> (requested_version === nothing || requested_version == ver)

# LAMMPS uses an ugly custom date-based versioning scheme, instead of SemVer or
# CalVer, so we map these to the CalVer equivalents.
versions_map = Dict("7Aug2019" => v"2019.8.7")


#===================#
#  LAMMPS 7Aug2019  #
#===================#

lammps_tag = "7Aug2019"
output[lammps_tag] = Dict()

version = versions_map[lammps_tag]

# Collection of sources required to complete build
sources = [
    FileSource("https://github.com/lammps/lammps/archive/stable_$(lammps_tag).tar.gz",
               "5380c1689a93d7922e3d65d9c186401d429878bb3cbe9a692580d3470d6a253f"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd lammps-*
mkdir build
cd build/

CXX_FLAGS=(-std=c++11)
if [[ "${target}" == *linux* ]]
then
    CXX_FLAGS+=(-lrt)
fi

CMAKE_FLAGS=(
    -DCMAKE_INSTALL_PREFIX=${prefix}
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_LIB=ON
    -DBUILD_SHARED_LIBS=ON
    -DCMAKE_CXX_FLAGS="${CXX_FLAGS[*]}"
    -DPKG_USER-INTEL=OFF
)

cmake -C ../cmake/presets/all_on.cmake -C ../cmake/presets/nolib.cmake "${CMAKE_FLAGS[@]}" ../cmake
make -j${proc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
cabi = CompilerABI(cxxstring_abi = :cxx11)
platforms = [
    Linux(:x86_64, libc = :glibc, compiler_abi = cabi),
    Linux(:aarch64, libc = :glibc, compiler_abi = cabi),
    Linux(:powerpc64le, libc = :glibc, compiler_abi = cabi)
]

# The products that we will ensure are always built
products = [
    LibraryProduct("liblammps", :liblammps),
    ExecutableProduct("lmp", :lammps)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency(PackageSpec(name = "FFMPEG_jll", uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"))
    Dependency(PackageSpec(name = "FFTW_jll", uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"))
    Dependency(PackageSpec(name = "MPICH_jll", uuid = "7cb0a576-ebde-5e09-9194-50597f1243b4"))
    Dependency(PackageSpec(name = "OpenBLAS_jll", uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"))
    Dependency(PackageSpec(name = "Zlib_jll", uuid = "83775a58-1f1d-513f-b197-d71354ab007a"))
    Dependency(PackageSpec(name = "libpng_jll", uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"))
]

# Build the tarballs, and possibly a `build.jl` as well.
if wants_version(version)
    merge!(output[lammps_tag],
           build_tarballs(ARGS, name, version, sources, script, platforms, products,
                          dependencies; preferred_gcc_version = v"5.2.0"))
end


#======================#
#  Generate artifacts  #
#======================#

using Pkg.Artifacts

bin_path = "https://github.com/pabloferz/LAMMPSBuilder/releases/download/v$(tag)"
artifacts_toml = joinpath(@__DIR__, "Artifacts.toml")

for tag in keys(output)
    src_name = "LAMMPS_$(tag)"

    for platform in keys(output[tag])
        tarball_name, tarball_hash, git_hash, products_info = output[tag][platform]
        download_info = Tuple[(joinpath(bin_path, basename(tarball_name)), tarball_hash)]
        bind_artifact!(artifacts_toml, src_name, git_hash;
                       platform = platform, download_info = download_info,
                       force = true, lazy = true)
    end
end
