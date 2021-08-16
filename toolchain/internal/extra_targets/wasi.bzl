WASI_SYSROOT_LINKS = {
    8: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-8/wasi-sysroot-8.0.tar.gz",
        "57fbc9b41f1daf99fa197ed026f105e38cbba0828333ffb3c24c835d660c5499",
    ),
    9: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-9/wasi-sysroot-9.0.tar.gz",
        "7aeaed38d3f4d02350460a6e8f2b73db8d732d30f659095fe58440d24d6dbdd7",
    ),
    10: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-10/wasi-sysroot-10.0.tar.gz",
        "d87ddfa3c460faa6960d2440b51370f626603635cff310138a9c14757d1307d9",
    ),
    11: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-11/wasi-sysroot-11.0.tar.gz",
        "7523bc938efa491108b519101208a8e1dec794041377eb05a6102620ce43220a",
    ),
    12: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-12/wasi-sysroot-12.0.tar.gz",
        "eed85df38110578a0366478c696cb755a6a01167a23ac1de70138b748401a2b4",
    ),
}

# A fallback (so that users can use the newer versions without us *having* to update this list):
def wasi_sysroot_url(llvm_major_version):
    return "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{v}/wasi-sysroot-{v}.0.tar.gz".format(v = llvm_major_version)

WASI_SYSROOT_EXTRACT_PATH = "sysroots/wasi"

# Returns a `Label` in the current repository pointing to the sysroot that was fetched.
def get_wasi_sysroot(rctx):
    llvm_version = rctx.attr.llvm_version
    llvm_major_version = int(llvm_version.split(".")[0])
    common_download_params = {
        "output": WASI_SYSROOT_EXTRACT_PATH,
        "stripPrefix": "wasi-sysroot",
        "canonical_id": str(llvm_major_version),
    }

    if llvm_major_version in WASI_SYSROOT_LINKS:
        url, sha = WASI_SYSROOT_LINKS[llvm_major_version]
        rctx.download_and_extract(
            url = url,
            sha256 = sha,
            **common_download_params
        )
    else:
        url = wasi_sysroot_url(llvm_major_version)
        print("We don't have a WASI sysroot URL for LLVM {}; we'll try to use `{}`..".format(llvm_major_version, url))

        res = rctx.download_and_extract(
            url = url,
            **common_download_params
        )

        print(
            "\n\nIt worked! Feel free to make a PR adding `{}` as the WASI URL for LLVM {} with sha256 = `{}`.\n\n".format(
                url,
                llvm_major_version,
                res.sha256
            )
        )

    rctx.file(
        WASI_SYSROOT_EXTRACT_PATH + "/BUILD",
        executable = False,
        content = """
filegroup(
  name = "sysroot",
  srcs = glob(["*/**"]),
  visibility = ["//visibility:public"],
)
""",
    )

    return "@" + rctx.attr.name + "//" + WASI_SYSROOT_EXTRACT_PATH + ":sysroot"


WASI_COMPILER_RT_LINKS = {
    8: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-8/libclang_rt.builtins-wasm32-wasi-8.0.tar.gz",
        "4b81bacf931820db80a41011320fc266117a3672eb5a4f4082caf533235a60f5",
    ),
    9: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-9/libclang_rt.builtins-wasm32-wasi-9.0.tar.gz",
        "b7d18202009f1528a4eb18c9a8551bb165d42475de27f6023156318f711b5abe",
    ),
    10: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-10/libclang_rt.builtins-wasm32-wasi-10.0.tar.gz",
        "4901bcf47107d6e696cf3900284b3fd5813caeb1f9d6f9f6b1960325b941429e",
    ),
    11: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-11/libclang_rt.builtins-wasm32-wasi-11.0.tar.gz",
        "6bf6998e5d9a4eacde44da4276c7c5be021c795e22243c689da905772a4be442",
    ),
    12: (
        "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-12/libclang_rt.builtins-wasm32-wasi-12.0.tar.gz",
        "5a0d8b8ce56be1615dc87acefaaa01573760d03e6f59de0e45207f775eea963b",
    ),
}

# A fallback (so that users can use the newer versions without us *having* to update this list):
def wasi_compiler_rt_url(llvm_major_version):
    return "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{v}/libclang_rt.builtins-wasm32-wasi-{v}.0.tar.gz".format(v = llvm_major_version)

def install_wasi_compiler_rt(rctx):
    pass
