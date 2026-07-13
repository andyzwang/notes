# frozen_string_literal: true

# Runs on the `:pre_render` hook, per-document, right before kramdown
# converts markdown to HTML (so this must run before markdown
# conversion, and must mutate raw markdown rather than rendered HTML).
# Turns ==something== in Markdown to <mark>something</mark> in output HTML.

Jekyll::Hooks.register [:notes], :pre_render do |doc|
  replace(doc)
end

Jekyll::Hooks.register [:pages], :pre_render do |doc|
  # jekyll considers anything at the root as a page,
  # we only want to consider actual pages
  next unless doc.path.start_with?('_pages/')
  replace(doc)
end

def replace(doc)
  # ==+  … ==+  are the surrounding markers (one or more `=` each side). The
  # captured group is the highlighted text: it must start with a non-space and
  # end with a char that isn't a space, `.`, or `=`. Forbidding the boundary
  # chars keeps the closing `==` markers and any trailing punctuation outside
  # the <mark>, and stops `== spaced ==` (padded) from matching.
  doc.content.gsub!(/==+([^ ](.*?)?[^ .=])==+/, "<mark>\\1</mark>")
end
