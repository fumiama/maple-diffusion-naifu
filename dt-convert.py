#!/usr/bin/env python3
import sys
if len(sys.argv) < 2: raise ValueError(f"Usage: {sys.argv[0]} path_to_ckpt")

from pathlib import Path
import torch as th

ckpt = th.load(sys.argv[1], map_location="cpu")
outpath = Path("output")
outpath.mkdir(exist_ok=True)

ks = []

# model weights
for k, v in ckpt["state_dict"].items():
    if "first_stage_model.encoder" in k: continue
    if not hasattr(v, "numpy"): continue
    if k.startswith("cond_stage_model.transformer"): ks.append(k)

for k in ks:
    v = ckpt["state_dict"][k]
    del ckpt["state_dict"][k]
    k = "cond_stage_model.transformer.text_model" + k[28:]
    print("renaming state_dict", k, end="\r")
    ckpt["state_dict"][k] = v

print("\nexporting...")

th.save(ckpt, str(outpath/"out.ckpt"))

print("Done!")
