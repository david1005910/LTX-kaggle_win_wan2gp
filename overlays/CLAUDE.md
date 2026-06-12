# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**WanGP** (by DeepBeepMeep) is a one-stop generative-media app: video (Wan 2.1/2.2, LTX-2, Hunyuan, LongCat, MagiHuman, …), image (Qwen Image, Z Image, Flux 1/2, HiDream, Ideogram4), audio/TTS (Qwen3 TTS, Ace Step, Omnivoice, Index TTS2, Chatterbox, …). Optimized for low-VRAM GPUs (down to ~6 GB) and works on RTX 10xx → 50xx, AMD ROCm, and MPS (experimental).

The current version is tracked in `wgp.py` (`WanGP_version`). Latest changes are documented in `README.md` "Latest Updates" and `docs/CHANGELOG.md`.

## Common commands

Conda env names and Python/Torch combos differ by GPU — see `docs/INSTALLATION.md`. The recommended modern stack is Python 3.11.14 / Torch 2.10 / CUDA 13.0 (`setup_config.json` is the source of truth for installer configurations).

```bash
# Launch web UI (default port 7860)
python wgp.py

# Headless: process a saved queue.zip or a settings .json
python wgp.py --process my_queue.zip [--output-dir ./out] [--dry-run] [--verbose 2]

# Start as MCP server (for agents)
python wgp.py --mcp --config <config dir> --output-dir <output dir>

# Interactive Deepy console (no web UI)
python wgp.py --ask-deepy

# Useful runtime flags
python wgp.py --attention {sdpa|flash|sage|sage2} --profile {1..5} --compile
python wgp.py --listen --server-port 8080 --share          # network/shared
python wgp.py --gpu cuda:1 --fp16 --perc-reserved-mem-max 0.3
```

There is no test suite, linter, or build step. Verification happens by running `wgp.py` (UI or `--process` headless) and observing output. Use `--dry-run` to validate a queue without generating.

Plugin catalog maintenance (rare):

```bash
python wgp.py --refresh-catalog          # check installed plugins for updates
python wgp.py --refresh-full-catalog     # check entire catalog
python wgp.py --merge-catalog            # merge plugins_local.json into plugins.json
```

## Architecture

WanGP is a single large Gradio app. Almost all UI wiring, queue handling, and orchestration live in **`wgp.py` (~13.6k lines)**; per-architecture model code lives under `models/<family>/`; cross-cutting infrastructure lives under `shared/`.

### The model registry

Models are described by **JSON definitions**, not Python classes:

- `defaults/*.json` — built-in model defaults (do not modify; see `defaults/ReadMe.txt`). The filename (minus `.json`) is the model **architecture id** / base model type (e.g. `vace_14B`, `ltx2_22B_distilled`, `i2v_2_2`).
- `finetunes/*.json` — user finetunes. Same shape as a default; properties merge over the matching default. See `docs/FINETUNES.md`.
- `models/_settings.json` — baseline schema underneath all model defs.

A **family handler** (`family_handler` class inside `models/<family>/*_handler.py`) declares which base model types it supports and how they relate. The master list of handlers is hardcoded in `wgp.py` (`family_handlers = [...]`, ~line 2281) and passed to `map_family_handlers()` which builds `model_types_handlers`, `families_infos`, `models_eqv_map` (bidirectional aliases), and `models_comp_map` (one-way "derived data type" compatibility). When adding a new model family, add it to that list and implement the `family_handler` static methods (`query_supported_types`, `query_family_maps`, `query_model_family`, `query_family_infos`, optional `register_lora_cli_args`).

`models/model_metadata.py` derives capability metadata (`media_inputs`, `outputs`, `capabilities`, …) from a model def — this is what the MCP / Python API exposes to agents.

### Generation pipeline

The hot path through `wgp.py`:

1. UI / API call assembles a settings dict, then `validate_settings()` (~line 852) and `process_prompt_and_add_tasks()` (~line 437) enqueue task(s).
2. `load_models(model_type, …)` (~line 3865) resolves the architecture, downloads checkpoints via `shared/utils/download.py` + `shared/utils/hf.py`, applies quantization (`shared/qtypes/*`), and constructs the pipeline.
3. `generate_video(...)` (~line 6428) runs the diffusion / TTS / image pipeline. It calls into the family handler's own `generate(...)` for the model in question.
4. Outputs are stored under `outputs/` and registered in the gallery. Metadata is embedded so existing files can be re-imported with their original settings.

GPU resource arbitration goes through `shared/utils/process_locks.py` (`acquire_GPU_ressources` / `release_GPU_ressources`) — long-running plugin tasks must use these helpers to coexist with the main generator (see `plugins/wan2gp-sample/plugin.py`).

### Shared infrastructure (`shared/`)

- `api.py` — in-process Python API (`shared.api.init()` returns a session; `session.run_task(settings)`); used by Deepy, headless runs, and the MCP server.
- `mcp_server.py` — MCP transport. `wgp.py --mcp` is the preferred entrypoint; `python -m shared.mcp_server` is a lower-level alternative.
- `cli_args.py` — argparse setup. Family handlers can register their own lora-dir CLI args via `register_lora_cli_args`.
- `match_archi.py` — tiny DSL for "this URL is for SM>=89 GPUs only", used in model defs to pick the right checkpoint per architecture.
- `attention.py` — selects sdpa / flash / sage / sage2 backend.
- `utils/plugins.py` — `WAN2GPPlugin` base class; plugin discovery / loading / catalog sync.
- `utils/loras_mutipliers.py`, `utils/frame_scheduler.py`, `utils/prompt_parser.py` — settings/prompt parsing including inline commands like `[/duration=…]`, `[/load_mem=…]`, `[25%:50%]…` (full grammar in `docs/PROMPTS.md`).
- `deepy/` — Deepy assistant (orchestrates the 6 generation tools with templates).
- `gradio/` — reusable UI components (galleries, hierarchy selector, finetune editor, magic-mask, model toolbar).
- `qtypes/`, `kernels/` — quantization handlers (fp8, nvfp4, bnb nf4, nunchaku int4/fp4, gguf) registered with `mmgp.quant_router`.
- `convert/` — checkpoint format conversion helpers.

### Models, preprocessing, postprocessing

- `models/<family>/` — one folder per architecture family. Handler in `*_handler.py`; pipeline / sampler / modules alongside. Family-specific JSON configs in `models/<family>/configs/`.
- `models/TTS/` — text-to-speech families (Ace Step, Chatterbox, Index TTS2, Omnivoice, …) and their handlers.
- `preprocessing/` — input prep (DWPose, Depth Anything v2/v3, Matanyone masks, RAFT flow, SAM3, MiDaS, scribble/canny, vocal separation, speaker separation, face preprocessing, Kokoro TTS for control).
- `postprocessing/` — RIFE (temporal), FlashVSR (spatial upscale), PiD (4× upscale), MMAudio (soundtrack), SeedVC (voice replacement), film grain.

### Plugins

Plugins are Python packages under `plugins/<plugin-name>/` with at minimum `__init__.py` and `plugin.py` exporting a `WAN2GPPlugin` subclass. They can add tabs, inject UI, request component handles, call exposed globals, and run their own GPU jobs. `plugins.json` is the community catalog (synced from the upstream repo); `plugins_local.json` (gitignored) is the local override layer. Built-in plugins ship under `plugins/wan2gp-*` and `wan2gp-sample` is a good reference. Full API in `docs/PLUGINS.md`.

## Editing conventions specific to this repo

- **Never edit `defaults/*.json`** to change model behavior — copy the file into `finetunes/` and override only the properties you want. The merge is property-by-property in favor of the finetune. `finetunes/` is gitignored.
- **`wgp.py` is intentionally monolithic.** Adding a feature usually means adding a function near the related ones rather than splitting modules. Look at neighbours of the line you're touching before refactoring.
- **Settings/version migrations.** `settings_version` in `wgp.py` is bumped when settings shape changes; older saved settings/queues go through `fix_settings(...)`. If you change a setting's meaning, add a migration there.
- **`mmgp` version pin matters.** `wgp.py` aborts at startup if `mmgp != target_mmgp_version`. Keep `requirements.txt` and `target_mmgp_version` in sync when bumping.
- **Plugin GPU work** must call `acquire_GPU_ressources` / `release_GPU_ressources` from `shared.utils.process_locks` to suspend the main generator and free VRAM cleanly.
- **MCP / API responses.** When extending `shared/api.py` or `shared/mcp_server.py`, expose capabilities through `models/model_metadata.py` so `wangp_list_models` / `wangp_get_model_schema` keep reflecting reality.
- **Inline prompt commands** (e.g. `[/store_mem]`, `[/duration=…]`, `[25%:50%]…`) are parsed in `shared/utils/prompt_parser.py` and `shared/utils/frame_scheduler.py`. Document new commands in `docs/PROMPTS.md`.

## Key files at a glance

- `wgp.py` — main app, UI, queue, generation orchestration. Entry point `if __name__ == "__main__":` at ~line 13372.
- `setup.py` / `setup_config.json` — installer (the GUI installer reads `setup_config.json`).
- `wgp_config.json` — runtime config the UI writes (gitignored copy lives in `--config` folder if specified).
- `models/_settings.json` — base settings schema; `docs/SETTINGS.md` is the field reference.
- `wangp-agent/SKILL.md` — recipe for agents using the MCP / Python API (preferred over the CLI).
- `docs/CLI.md`, `docs/MODELS.md`, `docs/FINETUNES.md`, `docs/PLUGINS.md`, `docs/PROMPTS.md`, `docs/DEEPY.md`, `docs/SETTINGS.md` — authoritative references for each subsystem.
