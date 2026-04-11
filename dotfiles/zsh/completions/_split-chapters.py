#compdef split-chapters.py
_arguments \
  '--input[Path to compiled full-book.md]: :_files -g "*.md"' \
  '--output[Output directory target]: :_files -/' \
  '--profile[YAML configuration profile]: :_files -g "*.yaml"' \
  '--save-endmatter[Salvage trailing markdown into endmatter]' \
  '--verbose[Print highly granular debugging matrices]' \
  '(-h --help)'{-h,--help}'[Display usage instructions]'
