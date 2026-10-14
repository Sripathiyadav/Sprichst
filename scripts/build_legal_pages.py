#!/usr/bin/env python3
"""Turns legal/*.md into plain web pages under web/legal/.

The stores and the law want a privacy policy at a public URL that opens without
the app, so Firebase Hosting serves these next to the app:

    https://<site>/legal/privacy-policy.html

Needs `pip install markdown`. Run it after editing anything in legal/ and commit
the result. `--check` fails if the pages are out of date (used by CI).
"""
import re
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "web" / "legal"
DOCS = [  # file, title (the order of the index page)
    ("privacy-policy", "Privacy Policy"),
    ("terms-of-service", "Terms of Service"),
    ("your-rights", "Your rights"),
    ("ai-transparency", "AI transparency"),
    ("cookies-and-storage", "Cookies and storage"),
    ("disclaimer", "Disclaimer"),
    ("copyright-and-takedown", "Copyright and takedown"),
    ("security-summary", "Security"),
    ("accessibility", "Accessibility"),
    ("impressum", "Impressum"),
    ("third-party-notices", "Open-source notices"),
]

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Sprichst</title>
<meta name="robots" content="index,follow">
<style>
 :root {{ color-scheme: light dark; --bg:#f2eae1; --ink:#1f1d1c; --muted:#5d5752; --line:#d9cfc4; --accent:#b8402f; }}
 @media (prefers-color-scheme: dark) {{ :root {{ --bg:#1f1d1c; --ink:#f2eae1; --muted:#b9b0a6; --line:#3a3633; --accent:#f08a7a; }} }}
 body {{ margin:0; background:var(--bg); color:var(--ink); font:17px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }}
 main {{ max-width:46rem; margin:0 auto; padding:2rem 1.25rem 4rem; }}
 nav {{ font-size:.95rem; margin-bottom:1.5rem; }}
 a {{ color:var(--accent); }}
 h1 {{ font-size:2rem; line-height:1.2; }} h2 {{ margin-top:2rem; }}
 table {{ border-collapse:collapse; width:100%; font-size:.95rem; }}
 th,td {{ border:1px solid var(--line); padding:.4rem .6rem; text-align:left; vertical-align:top; }}
 code {{ background:rgba(127,127,127,.15); padding:.1rem .3rem; border-radius:4px; }}
 footer {{ margin-top:3rem; color:var(--muted); font-size:.9rem; }}
</style>
</head>
<body><main>
<nav><a href="./">All documents</a> · <a href="../">Sprichst</a></nav>
{body}
<footer>Sprichst · Sripathi Vangapandla · <a href="mailto:sripathiyadav66@gmail.com">sripathiyadav66@gmail.com</a></footer>
</main></body></html>
"""


def render(md_text: str) -> str:
    return markdown.markdown(md_text, extensions=["tables", "sane_lists"])


def build() -> dict[Path, str]:
    pages = {}
    for slug, title in DOCS:
        body = render((ROOT / "legal" / f"{slug}.md").read_text())
        pages[OUT / f"{slug}.html"] = PAGE.format(title=title, body=body)
    links = "\n".join(f'<li><a href="{s}.html">{t}</a></li>' for s, t in DOCS)
    pages[OUT / "index.html"] = PAGE.format(
        title="Legal",
        body=f"<h1>Sprichst: legal documents</h1>\n<ul>\n{links}\n</ul>",
    )
    return pages


def main() -> int:
    pages = build()
    if "--check" in sys.argv:
        stale = [p.name for p, html in pages.items()
                 if not p.exists() or p.read_text() != html]
        if stale:
            print("web/legal is out of date:", ", ".join(stale),
                  "\nRun scripts/build_legal_pages.py and commit.")
            return 1
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for path, html in pages.items():
        path.write_text(html)
    print(f"wrote {len(pages)} pages to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
