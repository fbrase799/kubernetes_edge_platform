# Kubernetes project reference — AsciiDoc source (v2)

This edition is designed to resemble the original editorial one-page PDF using
**AsciiDoc + an Asciidoctor PDF YAML theme + editable SVG graphics**.

Keep the `.adoc`, `.yml`, and `.svg` files in one directory.

## Build with your existing Docker function

```bash
docker_adoc2pdf Frank_Brase_Kubernetes_Reference_v2.adoc
```

Or, without the wrapper:

```bash
docker run --rm -u "$(id -u):$(id -g)" \
  -e HOME=/tmp -e XDG_CACHE_HOME=/tmp \
  -v "$(pwd)":/documents/ asciidoctor/docker-asciidoctor \
  asciidoctor-pdf -r asciidoctor-mathematical \
  -a mathematical-format=svg Frank_Brase_Kubernetes_Reference_v2.adoc
```

Confirm that the PDF has exactly one page:

```bash
pdfinfo Frank_Brase_Kubernetes_Reference_v2.pdf | grep Pages
```

The theme deliberately uses the bundled `Noto Sans` font; no host fonts or
custom font installations are necessary. The header is explicit AsciiDoc text.
All artwork is SVG and editable without changing the AsciiDoc source.

## If your renderer still creates two pages

The exact pagination depends on the container image version. Try these, in order:

1. In `edge-reference-v2-theme.yml`, change `base.font-size` from `9.1` to `8.8`.
2. Set `page.margin` to `[28, 43, 36, 43]`.
3. In the `.adoc`, change the architecture image width from `100%` to `94%`.

Do not remove text from the source merely to fit the page.

## Layout elements

- Source `.adoc`: title, author, text, technical facts, architecture placement
- `edge-reference-v2-theme.yml`: fonts, colors, margins, headings and footer
- `Kubernetes_Reference_Metrics.svg`: three factual summary cards
- `Kubernetes_Edge_Platform_Architecture.svg`: editable architecture figure
- `Kubernetes_Reference_Rule.svg`: thin teal rule beneath the subtitle

This is a reference to completed hands-on work. It intentionally does not
present the separate, still-in-development `kubernetes_edge_plattform` project
as an accomplished deployment.
