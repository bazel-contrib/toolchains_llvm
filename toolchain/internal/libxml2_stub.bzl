# Copyright 2026 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Generate a stub libxml2.so.2 inside a downloaded LLVM distribution.

Prebuilt LLVM release binaries for Linux dynamically link ld.lld (and some
other tools) against libxml2.so.2, which lld only uses for Windows COFF
manifest merging. libxml2 2.14 changed its soname to libxml2.so.16, so on
hosts that ship only the new library (Ubuntu 25.10+, Arch, Fedora 41+),
ld.lld cannot start:

    ld.lld: error while loading shared libraries: libxml2.so.2:
    cannot open shared object file: No such file or directory

and on hosts with a compatibility symlink every link action prints:

    ld.lld: /lib/.../libxml2.so.2: no version information available

Upstream LLVM statically links libxml2 in release binaries as of
llvm-project commits 70cf763a42d5 and 4d7c1c6b08c0; the first release
carrying the change is 23.1.0 (scheduled 2026-08-25). All earlier LLVM
releases keep the dynamic dependency permanently.

This file constructs, in pure Starlark, a minimal ELF64 shared object that
defines the sixteen libxml2 symbols ld.lld imports, tagged with the
LIBXML2_2.4.30 / LIBXML2_2.6.0 version definitions the binary requests.
Written to lib/libxml2.so.2 in the distribution, it is found via ld.lld's
RUNPATH ($ORIGIN/../lib) ahead of any system search path, so the tools
start and run silently with no host libxml2 anywhere. The symbols are never
called on ELF targets; the functions' bodies are trap instructions and
xmlFree is a NULL pointer.

Nothing is executed to produce the file — the bytes are assembled here and
written with rctx.file — so generation works identically from any host OS,
including fetching a Linux toolchain from macOS or under remote execution.
"""

# A 256-entry table mapping a byte value to the 1-character string with that
# code point; Starlark has no chr(). rctx.file(..., legacy_utf8 = False)
# writes each code point below 256 as a single byte.
_ESC = "".join([
    "\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017",
    "\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037",
    "\040\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057",
    "\060\061\062\063\064\065\066\067\070\071\072\073\074\075\076\077",
    "\100\101\102\103\104\105\106\107\110\111\112\113\114\115\116\117",
    "\120\121\122\123\124\125\126\127\130\131\132\133\134\135\136\137",
    "\140\141\142\143\144\145\146\147\150\151\152\153\154\155\156\157",
    "\160\161\162\163\164\165\166\167\170\171\172\173\174\175\176\177",
    "\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217",
    "\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237",
    "\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257",
    "\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277",
    "\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317",
    "\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337",
    "\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357",
    "\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377",
])

# Symbols ld.lld imports from libxml2.so.2, by requested version.
_FUNCS_2_4_30 = [
    "xmlAddChild",
    "xmlCopyNamespace",
    "xmlDocDumpFormatMemoryEnc",
    "xmlDocGetRootElement",
    "xmlDocSetRootElement",
    "xmlFreeDoc",
    "xmlFreeNode",
    "xmlFreeNs",
    "xmlNewDoc",
    "xmlNewNs",
    "xmlNewProp",
    "xmlSetGenericErrorFunc",
    "xmlStrdup",
    "xmlUnlinkNode",
]
_FUNCS_2_6_0 = ["xmlReadMemory"]
_DATA_2_4_30 = ["xmlFree"]
_SONAME = "libxml2.so.2"
_V1 = "LIBXML2_2.4.30"
_V2 = "LIBXML2_2.6.0"

# ELF e_machine values per exec arch.
_EM = {
    "x86_64": 62,
    "aarch64": 183,
}

def _le(value, width):
    """value as width little-endian bytes (returned as a string)."""
    out = ""
    for i in range(width):
        out += _ESC[(value >> (8 * i)) & 255]
    return out

def _elf_hash(name):
    """The System V ELF hash used in version definition records."""
    h = 0
    for c in name.elems():
        codepoint = _ESC.find(c)
        h = (h << 4) + codepoint
        g = h & 0xf0000000
        if g:
            h = h ^ (g >> 24)
        h = h & (~g & 0xffffffff)
    return h

def _shdr(shoffs, name, typ, flags, addr, offset, size, link, info, align, entsize):
    return (_le(shoffs.get(name, 0), 4) + _le(typ, 4) + _le(flags, 8) +
            _le(addr, 8) + _le(offset, 8) + _le(size, 8) + _le(link, 4) +
            _le(info, 4) + _le(align, 8) + _le(entsize, 8))

def _sym(name_off, info, value, size, shndx):
    return (_le(name_off, 4) + _ESC[info] + _ESC[0] + _le(shndx, 2) +
            _le(value, 8) + _le(size, 8))

def libxml2_stub_bytes(arch):
    """Return the stub shared object for `arch` as a binary string.

    Write it with rctx.file(path, content = ..., legacy_utf8 = False).
    """
    if arch not in _EM:
        fail("libxml2_stub: unsupported exec arch '%s' (supported: %s)" %
             (arch, ", ".join(_EM.keys())))

    # ---- .dynstr: symbol, soname and version-definition names ----
    strtab = _ESC[0]
    offs = {}
    for name in _FUNCS_2_4_30 + _FUNCS_2_6_0 + _DATA_2_4_30 + [_SONAME, _V1, _V2]:
        offs[name] = len(strtab)
        strtab += name + _ESC[0]

    names = _FUNCS_2_4_30 + _FUNCS_2_6_0 + _DATA_2_4_30
    nsyms = 1 + len(names)

    # .gnu.version: version-definition index per dynsym entry
    # (0 = local, 1 = base/soname, 2 = LIBXML2_2.4.30, 3 = LIBXML2_2.6.0).
    versym_vals = ([0] + [2] * len(_FUNCS_2_4_30) + [3] * len(_FUNCS_2_6_0) +
                   [2] * len(_DATA_2_4_30))

    # Classic DT_HASH with one bucket; lookups walk the chain of all symbols.
    hash_words = [1, nsyms, 1, 0] + [i for i in range(2, nsyms)] + [0]
    hash_tab = "".join([_le(w, 4) for w in hash_words])

    ehdr_size = 64
    phdr_size = 56
    sym_size = 24
    shdr_size = 64
    phnum = 2  # PT_LOAD, PT_DYNAMIC
    shnum = 10

    # ---- file layout (offset == vaddr; single RWX PT_LOAD) ----
    off = ehdr_size + phnum * phdr_size
    hash_off = off
    off += len(hash_tab)
    dynsym_off = off
    off += nsyms * sym_size
    dynstr_off = off
    off += len(strtab)
    versym_off = (off + 1) // 2 * 2
    off = versym_off + 2 * nsyms
    verdef_off = (off + 7) // 8 * 8

    # .gnu.version_d: Verdef+Verdaux records for base, V1, V2.
    verdef_entry = 28  # sizeof(Elf64_Verdef) + sizeof(Elf64_Verdaux)
    verdef = ""
    defs = [(_SONAME, 1, 1), (_V1, 2, 0), (_V2, 3, 0)]  # (name, index, VER_FLG_BASE)
    for i in range(len(defs)):
        name, ndx, base = defs[i]
        vd_next = 0 if i == len(defs) - 1 else verdef_entry
        verdef += (_le(1, 2) + _le(base, 2) + _le(ndx, 2) + _le(1, 2) +
                   _le(_elf_hash(name), 4) + _le(20, 4) + _le(vd_next, 4))
        verdef += _le(offs[name], 4) + _le(0, 4)  # Verdaux
    off = verdef_off + len(verdef)

    text_off = (off + 15) // 16 * 16
    text = (_ESC[0x0f] + _ESC[0x0b]) * 8  # trap instructions; never executed
    off = text_off + len(text)
    data_off = (off + 7) // 8 * 8
    data = _ESC[0] * 8  # xmlFree = NULL
    off = data_off + len(data)
    dyn_off = (off + 7) // 8 * 8

    dyn_entries = [
        (4, hash_off),  # DT_HASH
        (5, dynstr_off),  # DT_STRTAB
        (6, dynsym_off),  # DT_SYMTAB
        (10, len(strtab)),  # DT_STRSZ
        (11, sym_size),  # DT_SYMENT
        (14, offs[_SONAME]),  # DT_SONAME
        (0x6ffffffc, verdef_off),  # DT_VERDEF
        (0x6ffffffd, 3),  # DT_VERDEFNUM
        (0x6ffffff0, versym_off),  # DT_VERSYM
        (0, 0),  # DT_NULL
    ]
    dyn = "".join([_le(t, 8) + _le(v, 8) for t, v in dyn_entries])
    load_end = dyn_off + len(dyn)

    # ---- section headers (unused by the loader; kept so readelf/nm work) ----
    shnames = [
        "",
        ".hash",
        ".dynsym",
        ".dynstr",
        ".gnu.version",
        ".gnu.version_d",
        ".text",
        ".data",
        ".dynamic",
        ".shstrtab",
    ]
    shstr = _ESC[0]
    shoffs = {}
    for n in shnames[1:]:
        shoffs[n] = len(shstr)
        shstr += n + _ESC[0]
    shstr_off = load_end
    shdr_off = (shstr_off + len(shstr) + 7) // 8 * 8

    shdrs = _shdr(shoffs, "", 0, 0, 0, 0, 0, 0, 0, 0, 0)
    shdrs += _shdr(shoffs, ".hash", 5, 2, hash_off, hash_off, len(hash_tab), 2, 0, 4, 4)
    shdrs += _shdr(shoffs, ".dynsym", 11, 2, dynsym_off, dynsym_off, nsyms * sym_size, 3, 1, 8, sym_size)
    shdrs += _shdr(shoffs, ".dynstr", 3, 2, dynstr_off, dynstr_off, len(strtab), 0, 0, 1, 0)
    shdrs += _shdr(shoffs, ".gnu.version", 0x6fffffff, 2, versym_off, versym_off, 2 * nsyms, 2, 0, 2, 2)
    shdrs += _shdr(shoffs, ".gnu.version_d", 0x6ffffffd, 2, verdef_off, verdef_off, len(verdef), 3, 3, 8, 0)
    shdrs += _shdr(shoffs, ".text", 1, 6, text_off, text_off, len(text), 0, 0, 16, 0)
    shdrs += _shdr(shoffs, ".data", 1, 3, data_off, data_off, len(data), 0, 0, 8, 0)
    shdrs += _shdr(shoffs, ".dynamic", 6, 3, dyn_off, dyn_off, len(dyn), 3, 0, 8, 16)
    shdrs += _shdr(shoffs, ".shstrtab", 3, 0, 0, shstr_off, len(shstr), 0, 0, 1, 0)
    file_end = shdr_off + shnum * shdr_size

    # ---- .dynsym ----
    dynsym = _sym(0, 0, 0, 0, 0)
    for n in _FUNCS_2_4_30 + _FUNCS_2_6_0:
        dynsym += _sym(offs[n], 0x12, text_off, 2, 6)  # GLOBAL FUNC in .text
    for n in _DATA_2_4_30:
        dynsym += _sym(offs[n], 0x11, data_off, 8, 7)  # GLOBAL OBJECT in .data
    versym = "".join([_le(v, 2) for v in versym_vals])

    # ---- program headers ----
    phdrs = (_le(1, 4) + _le(7, 4) + _le(0, 8) * 3 +
             _le(load_end, 8) * 2 + _le(0x1000, 8))  # PT_LOAD RWX
    phdrs += (_le(2, 4) + _le(6, 4) + _le(dyn_off, 8) * 3 +
              _le(len(dyn), 8) * 2 + _le(8, 8))  # PT_DYNAMIC RW

    # ---- ELF header: ET_DYN for the exec arch ----
    ehdr = (_ESC[0x7f] + "ELF" + _ESC[2] + _ESC[1] + _ESC[1] + _ESC[0] * 9 +
            _le(3, 2) + _le(_EM[arch], 2) + _le(1, 4) + _le(0, 8) +
            _le(ehdr_size, 8) + _le(shdr_off, 8) + _le(0, 4) +
            _le(ehdr_size, 2) + _le(phdr_size, 2) + _le(phnum, 2) +
            _le(shdr_size, 2) + _le(shnum, 2) + _le(shnum - 1, 2))

    img = ehdr + phdrs + hash_tab
    img += _ESC[0] * (dynsym_off - len(img)) + dynsym
    img += _ESC[0] * (dynstr_off - len(img)) + strtab
    img += _ESC[0] * (versym_off - len(img)) + versym
    img += _ESC[0] * (verdef_off - len(img)) + verdef
    img += _ESC[0] * (text_off - len(img)) + text
    img += _ESC[0] * (data_off - len(img)) + data
    img += _ESC[0] * (dyn_off - len(img)) + dyn
    img += _ESC[0] * (shstr_off - len(img)) + shstr
    img += _ESC[0] * (shdr_off - len(img)) + shdrs
    if len(img) != file_end:
        fail("libxml2_stub: internal layout error (%d != %d)" % (len(img), file_end))
    return img

def write_libxml2_stub(rctx, os, arch):
    """Write lib/libxml2.so.2 into the extracted distribution if applicable.

    Only Linux distributions are affected; on other exec platforms this is
    a no-op so the attribute can be set unconditionally.
    """
    if os != "linux":
        return
    rctx.file("lib/" + _SONAME, content = libxml2_stub_bytes(arch), legacy_utf8 = False)
