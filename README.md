# Cervical screening, diagnosis and treatment cascade: analysis code

Analysis code for a global, country-level test of whether cervical screening coverage is
associated with lower cervical cancer mortality **only where downstream diagnostic and
treatment capacity is present**, across 194 WHO member states, anchored to 2019–2021.

**The prespecified interaction was null.** In 164 complete-case countries, the screening by
capacity interaction was −0.0018 (robust SE 0.0039, p=0.649), a rate ratio of 0.998 (95% CI
0.991 to 1.006). The marginal screening association was indistinguishable from the null at
every level of capacity: a rate ratio per 10 percentage points of 1.005 (0.968 to 1.044) at
low capacity, 1.000 at median capacity and 0.998 (0.970 to 1.028) at high capacity. What did
predict mortality was burden and income: cervical cancer incidence (rate ratio 2.35, 2.11 to
2.61) and GDP per capita (0.90, 0.83 to 0.98).

**The null does not show that screening is ineffective, and the design is the reason.** A
cross-sectional 2019–2021 snapshot cannot capture the lag between screening, treatment and
later mortality, and direct precancer-treatment coverage was not available at country level,
so the capacity score stands in for it. The analysis is ecological and associational
throughout. It does not establish that screening or treatment capacity caused national
mortality differences, and WHO country profiles mix modelled outcome estimates with
country-reported health-system indicators, which is a further limit on how the capacity
measure should be read.

The analysis was gated before it ran. A prespecified stop rule required at least 80
complete-case countries, a screening interquartile range of at least 10 percentage points,
and at least 10 countries in each extreme capacity tertile. All three were met: 164
countries, an IQR of 67 percentage points, and 68 and 76 countries in the lower and upper
tertiles.

## What is in this repository

Only the analysis code, under `10_R-workflow/`.

```
10_R-workflow/
  run_pipeline.R            single entry point: data, models, outputs, parity check
  R/00_config.R             paths, seed, package assertions, shared utilities
  R/01_data.R               source retrieval, parsing, deterministic construction of the
                            analytic dataset and the derived capacity scores
  R/02_models.R             prespecified stop rule, negative-binomial interaction model with
                            HC3 robust covariance, marginal screening effects by capacity,
                            and propagation of WHO screening-estimate uncertainty
  R/03_reporting.R          descriptive and regional tables, joint-distribution figure
  R/04_verify.R             formal equivalence check against the Python baseline
  tests/test_parity.R       base-R test runner, no testthat dependency
  workflow.Rmd              executable explanation of the whole workflow
  DESCRIPTION               package dependencies
  renv.lock                 exact package versions
  PYTHON_EQUIVALENCE.md     stage-by-stage map from the Python implementation to this one
```

The outcome is the 2019 cervical cancer death count, modelled with a negative binomial using
log female population as an offset, with screening coverage, the capacity score, their
interaction, log incidence, log GDP, registry existence and WHO region indicators.

## What is not in this repository, and why

The data directories are absent by design. Raw source archives are third-party and are not
redistributed here, and the derived datasets, results, figures and manuscript drafts are not
published either.

Sources are the WHO cervical cancer country profiles (2021), the WHO Global Health
Observatory screening estimates (2019), the WHO Global Health Estimates and World Bank
development indicators. No endpoint used here requires credentials. Retrieval URLs, access
dates, file sizes and SHA-256 checksums for every source file are recorded in
`01_metadata/source_manifest.csv` in the full project tree. Raw source files are treated as
immutable and are never rewritten.

## Running it

Install `renv` once from CRAN, then restore the exact package versions:

```r
install.packages("renv")
renv::restore()
```

From the `10_R-workflow/` directory:

```bash
Rscript run_pipeline.R
Rscript tests/test_parity.R
Rscript -e "rmarkdown::render('workflow.Rmd')"
```

On Windows, substitute the full path to `Rscript.exe`, for example
`& 'C:\Program Files\R\R-4.6.0\bin\Rscript.exe' run_pipeline.R`.

The default run is fast. Three optional switches extend it:

- `--rebuild-data` reconstructs the analytic dataset from the upstream extracts instead of
  reading the retained one.
- `--uncertainty` runs 200 draws propagating the WHO screening-estimate intervals. This
  propagates measurement uncertainty in the exposure only and is not a full inferential
  interval.
- `--figures` writes the joint screening and capacity distribution figure.

The seed is fixed in `R/00_config.R`, so the uncertainty run is reproducible.

## Citation

This code accompanies a manuscript under submission. Please cite the article once published.

## Licence

MIT. See [LICENSE](LICENSE).

This covers the code in this repository only. The data sources it retrieves are third-party
and carry their own terms; see the provider in each case.
