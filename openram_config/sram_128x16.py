"""One reusable 1RW macro, instantiated twice in src_pyrope/sram_top.prp.

Set OPENRAM_TECH_NAME to a technology installed in your OpenRAM environment.
No technology is selected implicitly; physical generation has not been validated.
"""
import os
from pathlib import Path

word_size = 128
num_words = 16
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
num_banks = 1
words_per_row = 1
# Full-word writes: no write-mask pin in the generated Verilog interface.
write_size = word_size
tech_name = os.environ["OPENRAM_TECH_NAME"]
nominal_corner_only = True
check_lvsdrc = True
output_name = "sram_128x16"
output_path = str(Path(__file__).resolve().parents[1] / "generated" / "openram" / "macro")
