# htp_backend_ext_config.json — not reusable as-is

Found in `~/downloads/htp_backend_ext_config.json`. Two mismatches confirmed
2026-08-29, both would need fixing before reuse for a Gemma NPU run:

1. `graph_names: ["vit"]` — this targets a **Vision Transformer** graph, not an LLM
   graph. Wrong model type for Gemma text/audio inference.
2. `dsp_arch: "v73"`, `soc_id: 60` — this phone's actual Hexagon version is **v79**
   (confirmed via the Paage.ai APK teardown, which bundles QNN HTP skeletons for
   V73/V75/V79/V81 and this device resolves to V79). Wrong chip generation.

Don't hand-patch this file. Generate a fresh HTP backend config from Qualcomm's own
AI Hub / QAIRT tooling for the actual target model and this device's real
`dsp_arch`/`soc_id` — that's the "right tool, not the hard way" call made
2026-08-29 rather than editing a config built for different hardware and a
different model type.
