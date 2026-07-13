# frozen_string_literal: true

# Runs on the `:pre_render` hook, per-document, before Liquid and
# kramdown run (so it mutates raw markdown, like markdown_highlighter).
# Two jobs:
#
#   1. Auto-inject markdown="1" on every hand-written
#      <div class="note-header">, so the author never has to repeat it.
#      note-header is the "exclude from word count + preview" wrapper
#      (see excerpt_filters.rb); it may hold prose, not just an image.
#
#   2. Expand a compact image syntax into the div > img + caption
#      structure. Put it on its own line. Syntax:
#
#        ![alt](/assets/img/x.jpg)
#          -> body image, capped at 50vh
#        ![alt](/assets/img/x.jpg "*Caption* text")
#          -> + caption, styled like the old .main-image-caption
#        ![alt](/assets/img/x.jpg "*Caption*"){: .main link="https://..."}
#          .main       -> promote to a main image, capped at 70vh
#          link="..."  -> append a trailing <a href> to the caption
#
#      A leading-slash src is prefixed with {{ site.baseurl }} (Liquid
#      still runs after this hook, so the tag resolves normally). The
#      generated wrapper carries markdown="1", so caption markdown
#      (*italics*, [links](...)) is processed as usual.

Jekyll::Hooks.register [:notes], :pre_render do |doc|
  transform(doc)
end

Jekyll::Hooks.register [:pages], :pre_render do |doc|
  # jekyll considers anything at the root as a page,
  # we only want to consider actual pages
  next unless doc.path.start_with?('_pages/')
  transform(doc)
end

def transform(doc)
  inject_note_header_markdown(doc)
  expand_images(doc)
end

def inject_note_header_markdown(doc)
  # Add markdown="1" only to note-header divs that don't already have it.
  doc.content.gsub!(
    /<div class="note-header"(?![^>]*\bmarkdown=)/,
    '<div class="note-header" markdown="1"'
  )
end

IMAGE_TAG_RE = /
  !\[(?<alt>[^\]]*)\]           # ![alt]
  \(\s*(?<src>\S+?)             # (src
  (?:\s+"(?<caption>[^"]*)")?   # optional "caption"
  \s*\)                        # )
  (?:\{:\s*(?<ial>[^}]*)\})?    # optional {: .main link="..." }
/x

def expand_images(doc)
  doc.content = doc.content.gsub(IMAGE_TAG_RE) do
    m = Regexp.last_match
    alt = m[:alt].to_s.strip
    src = m[:src].to_s.strip
    caption = m[:caption]
    ial = m[:ial].to_s

    is_main = ial =~ /(?:\A|\s)\.main(?:\s|\z)/
    link = ial[/link="([^"]*)"/, 1]

    src = "{{ site.baseurl }}#{src}" if src.start_with?('/')
    img_class = is_main ? 'content-image main' : 'content-image'

    html = +%(<div class="image-wrapper" markdown="1">\n)
    html << %(<img class="#{img_class}" src="#{src}" alt="#{alt}"/>\n)
    if caption && !caption.strip.empty?
      anchor = link ? %(<a href="#{link}"></a>) : ''
      html << %(<span class="image-caption">#{caption.strip}#{anchor}</span>\n)
    end
    html << %(</div>)
    html
  end
end
