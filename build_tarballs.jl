using BinaryBuilder, Pkg

include("builder_defs.jl")
include("builder_tools.jl")

# Ignore deploy flags
filter!(arg -> !startswith(arg, "--deploy"), ARGS)

# Allow to build specific versions
requested_version = last(BinaryBuilder.extract_flag!(ARGS, "--version"))
wants_version = vn -> (
    requested_version === nothing || VersionNumber(requested_version) == vn
)

# Allow to specify subsets of platforms (useful for Travis CI)
requested_targets = extract_targets!(ARGS)
wants_target = t -> (isempty(requested_targets) || t in requested_targets)

#==============================#
#  Collect selected platforms  #
#==============================#
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

#======================#
#  Build the tarballs  #
#======================#
output = Dict()

for version in keys(versions_dict)
    if wants_version(version)
        tag = versions_dict[version]
        hash = hashes_dict[version]
        sources = [ArchiveSource(source_url(tag), hash)]
        output[version] = build_tarballs(
            ARGS, name, version, sources, script, platforms, products, dependencies
        )
    end
end

save(output)
