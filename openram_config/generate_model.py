"""Generate ONLY a behavioral model using the pinned OpenRAM Verilog writer.

This calls the writer with port/size metadata, bypassing physical SRAM creation.
It does not create GDS, LEF, SPICE, or Liberty, or validate macro feasibility.
The bundled scn4m_subm technology supplies power-pin names for model-only runs;
this is not a choice of fabrication target. Full generation uses sram_128x16.py
with OPENRAM_TECH_NAME explicitly set and a configured PDK/tool environment.
"""
import importlib.util
import os
from pathlib import Path
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import openram

os.environ.setdefault("OPENRAM_TECH_NAME", "scn4m_subm")
config = runpy.run_path(str(Path(__file__).with_name("sram_128x16.py")))
openram.OPTS.tech_name = config["tech_name"]
openram.import_tech()

# Load the upstream writer directly: importing openram.base also loads layout
# tools and numpy, which are unnecessary for emitting a behavioral model.
writer_path = ROOT / "openram" / "compiler" / "base" / "verilog.py"
spec = importlib.util.spec_from_file_location("openram_behavioral_writer", writer_path)
writer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(writer)
model = writer.verilog()
for name in ("word_size", "num_words", "write_size", "num_banks"):
    setattr(model, name, config[name])
assert model.word_size == 128 and model.num_words == 16 and model.write_size == 128
model.name = config["output_name"]
model.bank_addr_size = 4
model.num_spare_cols = 0
model.all_ports = model.readwrite_ports = model.read_ports = model.write_ports = [0]
# Keep model-only output separate from full compiler/physical output.
out = ROOT / "generated" / "openram"
out.mkdir(parents=True, exist_ok=True)
model.verilog_write(str(out / "sram_128x16.v"))

# Declaration only: LiveHD uses this interface for the imported hard macro.
# Simulation compiles the real OpenRAM model, not the empty declaration.
(out / "sram_128x16_ports.v").write_text(
    "(* blackbox *) module sram_128x16(\n"
    "  input clk0, csb0, web0, input [3:0] addr0,\n"
    "  input [127:0] din0, output [127:0] dout0\n"
    "); endmodule\n"
)
print(f"OpenRAM behavioral model and port declaration: {out}")
