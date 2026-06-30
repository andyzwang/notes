# frozen_string_literal: true
require 'nokogiri'

# Runs on the `:post_convert` hook, per-document, right after kramdown
# converts markdown to HTML (needs real HTML to parse with Nokogiri).
# If `open_external_links_in_new_tab` is truthy in _config.yml, add
# target="_blank" to anchor tags that don't have the `internal-link`
# class.

Jekyll::Hooks.register [:notes], :post_convert do |doc|
  convert_links(doc)
end

Jekyll::Hooks.register [:pages], :post_convert do |doc|
  # jekyll considers anything at the root as a page,
  # we only want to consider actual pages
  next unless doc.path.start_with?('_pages/')
  convert_links(doc)
end

def convert_links(doc)
  open_external_links_in_new_tab = !!doc.site.config["open_external_links_in_new_tab"]

  if open_external_links_in_new_tab
    parsed_doc = Nokogiri::HTML::DocumentFragment.parse(doc.content)
    parsed_doc.css("a:not(.internal-link):not(.footnote):not(.reversefootnote)").each do |link|
      link.set_attribute('target', '_blank')
    end
    doc.content = parsed_doc.inner_html
  end
end
