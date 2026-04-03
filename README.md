# ox-list-table

Write complex tables as nested lists in Org mode, export them as proper HTML `<table>` elements.

Org's built-in tables are great for simple grids, but they can't hold multi-line content, nested lists, images, or inline tables within a cell. `ox-list-table` solves this by letting you describe table structure as a plain list annotated with `#+ATTR_ODT: :list-table t`, then converting it to a real HTML table on export.

Cell content goes through Org's own export engine, so **all Org markup works inside cells** -- bold, italic, links, images with attributes, nested lists, inline tables, and more.

## Installation

### Manual

Download `ox-list-table.el` and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/ox-list-table/")
(require 'ox-list-table)
(org-list-table-enable)
```

### use-package

```elisp
(use-package ox-list-table
  :load-path "/path/to/ox-list-table/"
  :after ox-html
  :config
  (org-list-table-enable))
```

### Straight

```elisp
(use-package ox-list-table
  :straight (:host github :repo "wowhxj/ox-list-table")
  :after ox-html
  :config
  (org-list-table-enable))
```

## Usage

Mark a list with `#+ATTR_ODT: :list-table t`. The structure is:

- **Top-level items** (`-`) = rows
- **Second-level items** (`  -`) = cells within a row
- **Deeper content** under a cell = cell body (lists, images, tables, etc.)
- A top-level item starting with `- ----` (dashes) separates **thead** from **tbody**

### Minimal example

```org
#+ATTR_ODT: :list-table t
-
  - Name
  - Age
- --------
  - Alice
  - 30
- --------
  - Bob
  - 25
```

Exports to:

| Name  | Age |
|-------|-----|
| Alice |  30 |
| Bob   |  25 |

### Rich content in cells

Cells can contain any Org markup:

```org
#+CAPTION: Feature comparison
#+ATTR_ODT: :list-table t
-
  - Feature
  - Description
- ----------
  - *Authentication*
  - Supports [[https://oauth.net/2/][OAuth 2.0]] and SAML
- ----------
  -
    - Monitoring
    - /New in v2.0/
  -
    - Built-in dashboard with ~Grafana~ integration
    - Alerts via =PagerDuty=
      #+ATTR_HTML: :width 200
      [[file:img/dashboard.png]]
    | Metric    | Threshold |
    |-----------+-----------|
    | CPU       |       80% |
    | Memory    |       90% |
```

This demonstrates:

- **Bold** (`*...*`), **italic** (`/...`/), **code** (`~...~`, `=...=`) in cells
- **Links** to external URLs
- **Images** with `#+ATTR_HTML` attributes
- **Org tables** nested inside a cell
- **Multi-item cells** as nested lists
- **`#+CAPTION`** rendered as `<caption>`

## How it works

`ox-list-table` hooks into `org-export-before-parsing-functions`. Before Org parses the buffer for export, it:

1. **Detects** regions marked with `#+ATTR_ODT: :list-table t`
2. **Parses** the list structure into rows and cells, collecting raw Org source per cell
3. **Exports** each cell's content through `org-export-string-as`, so all Org markup is handled natively
4. **Replaces** the list region with a `#+BEGIN_EXPORT html` block containing the assembled `<table>`

This works with any HTML-derived backend: `html`, `reveal.js`, etc.

## Customization

### Table CSS class

```elisp
(setq org-list-table-html-table-class "my-table")
```

Default: `"dark-table"`. Applied as `<table class="...">`.

### Disable

```elisp
(org-list-table-disable)
```

## Supported backends

Any backend derived from `html`, including:

- `ox-html` (Org's built-in HTML export)
- `ox-reveal` (Reveal.js presentations)

## Requirements

- Emacs 27.1+
- Org 9.0+

## License

GPL-3.0. See [LICENSE](LICENSE).
