#compdef extract-book.sh
_arguments \
  '--book-pdf[Path to the source PDF file]: :_files -g "*.pdf"' \
  '--profile[Path to the book YAML profile]: :_files -g "*.yaml"' \
  '--output[Output directory for chapters-raw]: :_files -/' \
  '(-h --help)'{-h,--help}'[Display usage instructions]'
