#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${RISCV_PREFIX:-riscv64-unknown-elf-}"
CC="${PREFIX}gcc"
OBJCOPY="${PREFIX}objcopy"
OUT="${ROOT}/ctests/soc_c_test"

command -v "${CC}" >/dev/null || { echo "Missing ${CC}; set RISCV_PREFIX to your RISC-V toolchain prefix." >&2; exit 1; }
command -v "${OBJCOPY}" >/dev/null || { echo "Missing ${OBJCOPY}." >&2; exit 1; }

"${CC}" -march=rv32im -mabi=ilp32 -O1 -ffreestanding -fno-builtin \
    -fno-pic -mno-relax -nostdlib -nostartfiles -static \
    -Wl,--build-id=none -Wl,-T,"${ROOT}/ctests/soc_c_test.ld" \
    "${ROOT}/ctests/soc_c_start.S" "${ROOT}/ctests/soc_c_test.c" \
    -o "${OUT}.elf"
"${OBJCOPY}" -O ihex "${OUT}.elf" "${OUT}.ihex"
python3 "${ROOT}/ctests/ihex_to_memh.py" "${OUT}.ihex" "${OUT}.memh"
echo "Built ${OUT}.elf and ${OUT}.memh"
