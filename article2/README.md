# Article2: Predictional PHPA — Full Paper

This directory contains a complete, journal‑style LaTeX manuscript for the experimental, operator‑integrated Predictive Horizontal Pod Autoscaler (PHPA) work.

- Structured as section‑by‑section `.tex` files under `sections/`
- Integrates prior offline/online benchmark results and MSc findings
- Documents the Kubernetes operator implementation, CRDs, and models

## Build

- Compile with any LaTeX engine (e.g., `pdflatex` two times is sufficient):

```
cd article2
pdflatex main.tex
pdflatex main.tex
```

- Alternatively, open `main.tex` in your LaTeX IDE and build.

## Structure

- `main.tex` — preamble, abstract, and `\input{...}` includes
- `sections/` — individual sections:
  - 01-introduction.tex
  - 02-related-work.tex
  - 03-system-architecture.tex
  - 04-dataset-and-patterns.tex
  - 05-models-and-optimization.tex
  - 06-operator-implementation.tex
  - 07-experimental-setup.tex
  - 08-results-offline.tex
  - 09-results-online.tex
  - 10-discussion.tex
  - 11-limitations.tex
  - 12-symbols.tex
  - 13-conclusions.tex
  - 14-acknowledgments-references.tex

Notes:
- All files are UTF‑8 and follow the article rules in `article/article-rules.md` where applicable.
- Symbols and references are consolidated into dedicated sections to keep the flow tidy and compatible with journal submission.
