# frozen_string_literal: true

# Liquid filters used by _layouts/note.html to build excerpts (the
# "Mentioned in" preview text) and the word count metadata row. Not
# tied to a specific Jekyll build phase — these run wherever they're
# called from a template.
module ExcerptFilters
  def strip_note_header(input)
    input.to_s.gsub(%r{<div[^>]*class=["'][^"']*\bnote-header\b[^"']*["'][^>]*>.*?</div>}im, '')
  end

  def strip_footnotes(input)
    input.to_s
      .gsub(%r{<sup id=["']fnref[^"']*["'][^>]*>.*?</sup>}im, '')
      .gsub(%r{<div[^>]*class=["'][^"']*\bfootnotes\b[^"']*["'][^>]*>.*?</div>}im, '')
  end

  def note_word_count(input)
    text = strip_footnotes(strip_note_header(input)).gsub(/<[^>]+>/, ' ')
    text.split(/\s+/).reject(&:empty?).size
  end

  # `.excerpt` is cached from the raw markdown file at read-time, before
  # the wiki-link generator or kramdown ever run on it, so [[name]] and
  # [[name|display]] syntax shows up unconverted. Replace it with the
  # plain display text rather than leaving the brackets in place.
  def strip_wikilinks(input)
    input.to_s.gsub(/\[\[[^\]|]+\|([^\]]+)\]\]|\[\[([^\]]+)\]\]/) { $1 || $2 }
  end

  # Strip all HTML tags except <em>, so italics survive into excerpts.
  def strip_html_keep_em(input)
    input.to_s.gsub(%r{</?(?!em\b)[a-zA-Z][^>]*>}i, '')
  end
end

Liquid::Template.register_filter(ExcerptFilters)
