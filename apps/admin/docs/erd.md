# ERD and Model Annotations

## Generate ERD

Rails ERD requires Graphviz to render PNG files.

- Ensure Graphviz is installed (`dot -V`).
- From `apps/admin`, run:

```bash
bash script/erd.sh
```

Output: `docs/erd.png`.

Note: ERD generation uses `RAILS_LOAD_PATHS` plus an explicit `--only` list to avoid Solid* eager-load warnings. Update the model list in `script/erd.sh` when new app models are added.

## Annotate Models

Annotations are configured to appear at the bottom of model files via `.annotate`.

- From `apps/admin`, run:

```bash
bash script/annotate.sh
```
