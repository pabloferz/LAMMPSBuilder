using BinaryBuilder
using GitHub
using Pkg
using Random
using ghr_jll

const BB = BinaryBuilder
const GH = GitHub

function extract_targets!(args)
    targets = filter(arg -> !startswith(arg, "--"), args)
    # Remove collected targets from ARGS as we handle them directly
    filter!(arg -> startswith(arg, "--"), args)
    return targets
end

function save(output, name = "build_output.jl")
    # Indent levels
    s¹ = "    "
    s² = s¹ * s¹
    s³ = s² * s¹
    s⁴ = s² * s²
    s⁵ = s³ * s²

    open(name, "w") do io
        write(io, "using BinaryBuilder\n")
        write(io, "using Pkg\n\n")
        write(io, "using Base: SHA1\n\n")
        write(io, "output = Dict(\n")
        for version in keys(output)
            write(io, s¹, repr(version), " => Dict(\n")
            platforms_products = output[version]
            for platform in keys(platforms_products)
                p = platforms_products[platform]
                write(io, s², repr(platform), " => (\n")
                write(io, s³, repr(p[1]), ",\n")
                write(io, s³, repr(p[2]), ",\n")
                write(io, s³, repr(p[3]), ",\n")
                write(io, s³, "Dict(\n")
                products = p[4]
                for product in keys(products)
                    # The `LibraryProduct` constructor does not match its string
                    # representation
                    if product isa BinaryBuilder.LibraryProduct
                        write(io, s⁴, "LibraryProduct(\n")
                        write(io, s⁵, repr(product.libnames), ", ")
                        write(io, repr(product.variable_name), ", ")
                        write(io, repr(product.dir_paths), ";\n")
                        write(io, s⁵, "dont_dlopen = ", repr(product.dont_dlopen), ", ")
                        write(io, "dlopen_flags = ", repr(product.dlopen_flags), "\n")
                        write(io, s⁴, ")")
                    else
                        write(io, s⁴, repr(product))
                    end
                    write(io, " => Dict(\n")
                    for pair in products[product]
                        write(io, s⁵, repr(pair), ",\n")
                    end
                    write(io, s⁴, "),\n")
                end
                write(io, s³, "),\n")
                write(io, s², "),\n")
            end
            write(io, s¹, "),\n")
        end
        write(io, ")")
    end
end

function build_jlls(ARGS, name, output, dependencies)
    args = copy(ARGS)
    verbose = BB.check_flag!(args, "--verbose")
    gh_account = last(BB.extract_flag!(args, "--gh-account", "JuliaBinaryWrappers"))

    jll_repo = "$(gh_account)/$(name)_jll.jl"
    jll_path = joinpath(Pkg.devdir(), "$(name)_jll")

    BB.init_jll_package(name, jll_path, jll_repo)

    versions = (sort! ∘ collect ∘ keys)(output)
    for version in versions
        platforms_products = output[version]
        build_version = get_next_version(jll_repo, version)
        build_tag = "v$(build_version)"
        url = "https://github.com/$(jll_repo)/releases/download/$(build_tag)"

        if verbose
            message = (
                "Committing and pushing $(name)_jll.jl wrapper code version " *
                "$(build_version)..."
            )
            @info(message)
        end
        BB.build_jll_package(
            name, build_version, jll_path, platforms_products, dependencies, url;
            verbose = verbose
        )
        BB.push_jll_package(
            name, build_version; code_dir = jll_path, deploy_repo = jll_repo
        )

        # Copy current version tarballs to a temporary path to prevent tarball mixing
        name_version = "$(name).v$(version)"
        products_path = joinpath(pwd(), "products")
        tmp_path = joinpath(products_path, randstring())
        mkpath(tmp_path)
        for tarball in readdir(products_path)
            if startswith(tarball, name_version)
                src = joinpath(products_path, tarball)
                dst = joinpath(tmp_path, tarball)
                cp(src, dst; force = true)
            end
        end

        if verbose
            @info("Deploying tarballs to release $(build_tag) on $(jll_repo) via `ghr`...")
        end
        BB.upload_to_github_releases(jll_repo, build_tag, tmp_path; verbose = verbose)

        # Clean up
        rm(tmp_path; recursive = true, force = true)
    end
end

function get_next_version(repo, version)
    # If version already has a build_number, try using it
    build_number = UInt(0)
    if version.build != ()
        build_number = first(version.build)
    end

    # Download tag list from GitHub
    refs = first(GH.gh_get_paged_json(GH.DEFAULT_API, "/repos/$(repo)/git/refs"))
    filter!(r -> occursin(r"tags/v", r["ref"]), refs)

    # Collect the versions that match ours
    versions = VersionNumber[]
    for r in refs
        v = VersionNumber(last(rsplit(r["ref"], '/'; limit = 2)))
        version_matches = (
            v.major == version.major && v.minor == version.minor &&
            v.patch == version.patch && v.build isa Tuple{UInt}
        )
        if version_matches
            push!(versions, v)
        end
    end

    # Our build number must be larger that the maximum already deployed
    if !isempty(versions)
        last_build_number = first(maximum(versions).build)
        if build_number ≤ last_build_number
            build_number = last_build_number + UInt(1)
        end
    end

    return VersionNumber(
        version.major, version.minor, version.patch, version.prerelease, (build_number,)
    )
end
