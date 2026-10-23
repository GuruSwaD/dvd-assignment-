# 4-bit Array Multiplier — RTL to GDSII (SKY130)

| | |
|---|---|
| **Name** | `<NAME>` |
| **Roll number** | `<ROLL_NUMBER>` |
| **Design** | `mult_array`: 4-bit × 4-bit unsigned array multiplier, registered inputs and output (latency 2 cycles) |
| **Technology** | SkyWater SKY130, `sky130_fd_sc_hd`, typical corner `tt_025C_1v80` |

## Repository layout

```
rtl/full_adder.v            full adder (assign statements)
rtl/mult_array.v            array multiplier: 16 AND gates, 12 full_adder instances, 16 flip-flops
tb/tb_mult.v                exhaustive self-checking testbench (256 vectors)
synth/synth.tcl             Yosys script        -> mult_array_netlist.v, mult_array_stat.rpt
sta/sta.tcl                 OpenSTA script      -> mult_array_timing.rpt
pnr/config.json             LibreLane config    -> metrics.json, mult_array.gds (copied from the final run)
report/report.pdf           report
```

## Environment

The tools (Icarus Verilog, Yosys 0.62, OpenSTA 2.7.0, LibreLane 3.0.16 with OpenROAD, Magic, Netgen and
KLayout) were run on Windows 11 inside WSL 2 (Ubuntu 24.04) using LibreLane's official Nix environment through
[nix-portable](https://github.com/DavHau/nix-portable), because Docker was not available. The SKY130 PDK is
open_pdks `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`, the version pinned by LibreLane 3.0.16.
The commands for each step are exactly the ones from the assignment guide, so they also work unchanged
inside the IIC-OSIC-TOOLS Docker image.

One-time setup (in WSL, no root needed):

```bash
# nix-portable + the FOSSi binary cache
mkdir -p ~/bin && curl -L https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-$(uname -m) -o ~/bin/nix-portable
chmod +x ~/bin/nix-portable
mkdir -p ~/.config/nix && cat > ~/.config/nix/nix.conf <<EOF
extra-substituters = https://nix-cache.fossi-foundation.org
extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
extra-experimental-features = nix-command flakes
EOF

# LibreLane and its tool environment
git clone --depth 1 https://github.com/librelane/librelane ~/librelane
cd ~/librelane && NP_RUNTIME=bwrap ~/bin/nix-portable nix develop      # opens a shell with all tools

# inside that shell: SKY130 PDK
export PDK_ROOT=~/.ciel PDK=sky130A
ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
```

Every command below is run from the repository root inside that shell (`echo $PDK_ROOT $PDK` → `~/.ciel sky130A`).

Tool check (Section 4.2):

```bash
iverilog -V | head -1        # Icarus Verilog version 13.0 (devel)
yosys -V                     # Yosys 0.62
sta -version                 # 2.7.0
echo $PDK_ROOT $PDK          # /home/<user>/.ciel sky130A
```

## Part A — RTL design and verification

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                      # PASS: 256 vectors checked, 0 errors
gtkwave mult.vcd
```

Error-injection test (task 6): `assign sum = a ^ b ^ cin;` in `rtl/full_adder.v` was temporarily changed to
`assign sum = a ^ b;`, the same two commands were run, and the testbench printed

```
MISMATCH at 1060 ns: a=3 b=3 p=5 expected=9
...
FAIL: 256 vectors checked, 95 errors
```

The change was then undone and the testbench printed PASS again.

## Part B — Logic synthesis

```bash
yosys -c synth/synth.tcl
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls                      # PASS: 256 vectors checked, 0 errors
```

Result: 70 cells, 16 × `dfrtp_1`, 797.014 µm² total, flip-flops 400.384 µm² (50.24 %).

## Part C — Static timing analysis

`sta/sta.tcl` uses a 10 ns clock by default; the period can be overridden with the `PERIOD` environment variable.

```bash
sta sta/sta.tcl                    # worst slack max 7.017  -> T_min = 10 - 7.017 = 2.983 ns, F_max = 335.2 MHz
PERIOD=2.98 sta sta/sta.tcl        # worst slack max -0.003 (≈ 0, confirms T_min)
sta sta/sta.tcl                    # re-run at 10 ns so sta/mult_array_timing.rpt is the T = 10 ns report
```

## Part D — Physical design (LibreLane)

```bash
cd pnr
librelane --pdk-root $PDK_ROOT config.json      # same as: librelane config.json
cp runs/<RUN>/final/metrics.json .
cp runs/<RUN>/final/gds/mult_array.gds .
klayout mult_array.gds
```

Initial CLOCK_PERIOD = 1.2 × T_min = 1.2 × 2.983 = 3.58 ns → rounded up to the next 0.5 ns = **4.0 ns**.
LibreLane signs off at nine corners; `timing__setup__ws` in metrics.json is the worst one (slow corner
`ss_100C_1v60`). Following the guide, CLOCK_PERIOD was increased by 0.5 ns per run until it was ≥ 0.

Every attempt:

| Run | Run folder | CLOCK_PERIOD (ns) | Setup slack, worst corner (ns) | Setup slack, tt corner (ns) | Setup violations | Magic / KLayout DRC | LVS | Result |
|---|---|---|---|---|---|---|---|---|
| 1 | `RUN_2026-10-23_21-30-54` | 4.0 | -1.254 | +1.167 | 15 | 0 / 0 | 0 | setup violated → +0.5 ns |
| 2 | `RUN_2026-10-23_21-33-00` | 4.5 | -0.754 | +1.667 | 12 | 0 / 0 | 0 | setup violated → +0.5 ns |
| 3 | `RUN_2026-10-23_21-34-21` | 5.0 | -0.254 | +2.167 | 9 | 0 / 0 | 0 | setup violated → +0.5 ns |
| 4 | `RUN_2026-10-23_21-35-43` | 5.5 | -0.009 | +2.595 | 1 | 0 / 0 | 0 | setup violated → +0.5 ns |
| 5 | `RUN_2026-10-23_21-37-01` | 6.0 | -0.001 | +2.929 | 1 | 0 / 0 | 0 | setup violated → +0.5 ns |
| 6 | `RUN_2026-10-23_21-38-16` | 6.5 | +0.499 | +3.429 | 0 | 0 / 0 | 0 | **timing met — final run** |

At 5.5 ns and 6.0 ns the slack stopped improving by the full 0.5 ns because LibreLane's synthesis and resizer are
timing-driven: with a longer period they pick smaller, slower cells, so the slow-corner path `a_r[2] -> p[7]`
grew with the period. Final submission files: `pnr/metrics.json` and `pnr/mult_array.gds` from
`RUN_2026-10-23_21-38-16/final/`, with `CLOCK_PERIOD = 6.5` in `pnr/config.json`.

The `runs/` folder is not committed (see `.gitignore`).
