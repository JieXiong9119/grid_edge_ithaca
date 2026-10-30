# Reports, not pipeline data

- diagnostics: AMI duplicate/gap reports, aggregation checks, meter status/source traces.
- metadata: notebook 1.1 distribution plots and selected-meter tables.
- postprocess: notebook 5 scenario comparison figures and CSV summaries.
- logs: preserved batch execution logs.

Final load tables live in the processed data stage, not here. Published figure copies remain in [../docs/figures/postprocess/](../docs/figures/postprocess/). Report payloads are git-ignored; see [../docs/data_flow.md](../docs/data_flow.md) for contracts and provenance.