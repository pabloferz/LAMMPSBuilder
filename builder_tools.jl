function extract_targets!(args)
    targets = filter(arg -> !startswith(arg, "--"), ARGS)
    # Remove collected targets from ARGS as we handle them directly
    filter!(arg -> startswith(arg, "--"), ARGS)
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
        write(io, "output = Dict(\n")
        for version in keys(output)
            write(io, s¹, repr(version), " => Dict(\n")
            platform_products = output[version]
            for platform in keys(platform_products)
                p = platform_products[platform]
                write(io, s², repr(platform), " => (\n")
                write(io, s³, repr(p[1]), ",\n")
                write(io, s³, repr(p[2]), ",\n")
                write(io, s³, "Base.", repr(p[3]), ",\n")
                write(io, s³, "Dict(\n")
                products = p[4]
                for product in keys(products)
                    # The `LibraryProduct` constructor does not match its string
                    # representation
                    if product isa BinaryBuilder.LibraryProduct
                        write(io, s⁴, "BinaryBuilder.LibraryProduct(\n")
                        write(io, s⁵, repr(product.libnames), ", ")
                        write(io, repr(product.variable_name), ", ")
                        write(io, repr(product.dir_paths), ";\n")
                        write(io, s⁵, "dont_dlopen = ", repr(product.dont_dlopen), ", ")
                        write(io, "dlopen_flags = ", repr(product.dlopen_flags), "\n)")
                    else
                        write(io, s⁴, "BinaryBuilder.", repr(product))
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
