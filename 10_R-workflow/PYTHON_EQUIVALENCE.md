# Python-to-R coverage: Project 02

| Active Python responsibility | R equivalent |
|---|---|
| `04_code/run_pipeline.py`, orchestration in `study.py` | `run_pipeline.R` |
| source retrieval, parsing and deterministic data construction in `study.py` | `R/01_data.R` |
| stop rule and statistical models in `study.py` | `R/02_models.R` |
| tables and figures in `study.py` | `R/03_reporting.R` |
| scientific/output verification in `study.py` and `verify_manuscript.py` | `R/04_verify.R` |
| `04_code/tests/test_study.py` | `tests/test_parity.R` |
| integrated executable explanation | `workflow.Rmd` |

The Python-only DOCX layout code in `build_documents.py` and raster PDF contact
sheet utility in `render_qa_sample.py` are presentation utilities, not active
scientific/data logic. The R verifier retains the scientifically relevant
visible-text check via Pandoc.
