#!/usr/bin/env python3
"""Print the C symbols extension SQL declares that a shared library does not define.

    missing_c_symbols.py LIBRARY SQL...

A declared symbol is the second string of an `AS 'MODULE_PATHNAME', '<symbol>'`
or `AS '$libdir/libhfm-...', '<symbol>'` clause. A defined symbol is a dynamic
symbol of LIBRARY (a little-endian ELF64 file) bound to a section, as
`nm -D --defined-only` lists them; the HAF image has no binutils.
Missing symbols are printed one per line, sorted; the exit status is 0 either way.
"""
import re
import struct
import sys

DECLARED = re.compile(r"'(?:MODULE_PATHNAME|\$libdir/libhfm[^']*)'\s*,\s*'([A-Za-z0-9_]+)'")
SHT_DYNSYM = 11
SHN_UNDEF = 0


def declared_symbols(paths: list[str]) -> set[str]:
    symbols = set()
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            symbols.update(DECLARED.findall(handle.read()))
    return symbols


def defined_symbols(path: str) -> set[str]:
    with open(path, "rb") as handle:
        elf = handle.read()
    if elf[:4] != b"\x7fELF" or elf[4] != 2 or elf[5] != 1:
        raise ValueError(f"{path}: not a little-endian ELF64 file")
    shoff, = struct.unpack_from("<Q", elf, 0x28)
    shentsize, shnum = struct.unpack_from("<HH", elf, 0x3A)
    sections = [struct.unpack_from("<IIQQQQIIQQ", elf, shoff + i * shentsize) for i in range(shnum)]
    symbols = set()
    for _, sh_type, _, _, offset, size, link, _, _, entsize in sections:
        if sh_type != SHT_DYNSYM:
            continue
        strtab = sections[link][4]
        for pos in range(offset, offset + size, entsize):
            st_name, _, _, st_shndx = struct.unpack_from("<IBBH", elf, pos)
            if st_shndx != SHN_UNDEF and st_name:
                symbols.add(elf[strtab + st_name:elf.index(b"\0", strtab + st_name)].decode())
    return symbols


def main(library: str, sql: list[str]) -> None:
    for symbol in sorted(declared_symbols(sql) - defined_symbols(library)):
        print(symbol)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(f"usage: {sys.argv[0]} LIBRARY SQL...")
    main(sys.argv[1], sys.argv[2:])
