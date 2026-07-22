# frozen_string_literal: true

# Runs as a Jekyll Generator (during the `site.generate` phase, before
# any document is rendered to HTML).
#
# Resolves [[Wiki Link]] / [[name|Display]] syntax into real anchor tags
# (or greyed-out "ghost" links to not-yet-written notes), and computes
# the backlinks + graph data used by the "Mentioned in" sidebar and the
# notes graph.
#
# Performance note: this does a single pass over each note (building a
# name -> doc lookup index once, then resolving + recording backlinks as
# it goes), rather than the O(notes^2) nested-loop-over-every-pair
# approach this previously used. That matters once the notes collection
# grows past a few dozen files.
class BidirectionalLinksGenerator < Jekyll::Generator
  # Frontmatter fields whose wikilinks should be resolved the same way
  # as note body content (e.g. `author: "[[Homer]]"`)
  METADATA_FIELDS = ['author'].freeze

  WIKILINK_REGEX = /\[\[([^\]]+)\]\]/.freeze

  def generate(site)
    @site = site
    @all_notes = site.collections['notes'].docs
    @all_docs = @all_notes + site.pages
    @link_extension = site.config['use_html_extension'] ? '.html' : ''

    @lookup = build_lookup_index(@all_docs)
    @ghost_nodes = {}
    @graph_edges = []
    @backlinks = Hash.new { |h, k| h[k] = [] }

    @all_docs.each { |doc| resolve_links_in_doc(doc) }
    resolve_passages_links(site.data['passages'])

    assign_backlinks
    write_graph_data
  end

  private

  # Build a normalized-name => doc index so each note's links can be
  # resolved with a single hash lookup instead of scanning every other
  # note. Names are normalized so spaces/underscores/hyphens are
  # interchangeable (e.g. "the-political" / "the_political" / "the
  # political" all resolve to the same doc), and lookups are
  # case-insensitive.
  def build_lookup_index(docs)
    index = {}
    docs.each do |doc|
      filename = File.basename(doc.basename, File.extname(doc.basename))
      index[normalize(filename)] = doc

      title = doc.data['title']
      index[normalize(title)] = doc if title.is_a?(String)
    end
    index
  end

  def normalize(str)
    str.to_s.downcase.gsub(/[-_\s]+/, ' ').strip
  end

  def resolve_links_in_doc(doc)
    doc.content = doc.content.gsub(WIKILINK_REGEX) { replace_wikilink(doc, Regexp.last_match(1)) }

    METADATA_FIELDS.each do |field|
      value = doc.data[field]
      next unless value.is_a?(String)

      doc.data[field] = value.gsub(WIKILINK_REGEX) { replace_wikilink(doc, Regexp.last_match(1)) }
    end
  end

  # /passages/ shows an author + source per entry. Both get an `_link` field
  # alongside the original (which stays plain text — it still feeds `slugify`
  # for the anchor id and the A-Z rail's letter grouping, so it can't become
  # HTML). [[Target|Display]] overrides the match, same syntax as note bodies;
  # otherwise plain text auto-links if it matches a note by title.
  def resolve_passages_links(passages)
    return unless passages.is_a?(Array)

    passages.each do |passage|
      passage['author_link'] = resolve_maybe_wikilink(passage['author'])
      passage['source_link'] = resolve_maybe_wikilink(passage['source'])

      next unless passage['quotes'].is_a?(Array)

      passage['quotes'].each { |q| q['source_link'] = resolve_maybe_wikilink(q['source']) }
    end
  end

  def resolve_maybe_wikilink(value)
    return value unless value.is_a?(String)
    return value.gsub(WIKILINK_REGEX) { replace_wikilink(nil, Regexp.last_match(1)) } if value.match?(WIKILINK_REGEX)

    target = @lookup[normalize(value)]
    return value unless target

    "<a class='internal-link' href='#{@site.baseurl}#{target.url}#{@link_extension}'>#{value}</a>"
  end

  # `inner` is whatever was inside the double brackets, e.g. "Homer" or
  # "the-political|the political".
  def replace_wikilink(doc, inner)
    name, display = inner.split('|', 2)
    display ||= name
    target = @lookup[normalize(name)]

    if target
      register_backlink(doc, target)
      href = "#{@site.baseurl}#{target.url}#{@link_extension}"
      "<a class='internal-link' href='#{href}'>#{display}</a>"
    else
      register_ghost_link(doc, name) if @all_notes.include?(doc)
      "<span title='There is no note that matches this link.' class='invalid-link'>" \
        "<span class='invalid-link-brackets'>[[</span>#{display}<span class='invalid-link-brackets'>]]</span></span>"
    end
  end

  def register_backlink(doc, target)
    return unless @all_notes.include?(doc) && @all_notes.include?(target)
    return if doc.url == target.url
    return if @backlinks[target.url].include?(doc)

    @backlinks[target.url] << doc
    @graph_edges << { source: note_id_from_note(doc), target: note_id_from_note(target) }
  end

  def register_ghost_link(doc, name)
    clean_name = name.strip
    return if clean_name.empty?

    key = clean_name.downcase
    @ghost_nodes[key] ||= {
      id: "ghost-#{key.bytes.join}",
      path: nil,
      label: clean_name,
      ghost: true,
    }

    @graph_edges << { source: note_id_from_note(doc), target: @ghost_nodes[key][:id] }
  end

  def assign_backlinks
    @all_notes.each { |note| note.data['backlinks'] = @backlinks[note.url] }
  end

  def write_graph_data
    graph_nodes = @all_notes
      .reject { |note| note.path.include?('_notes/index.html') }
      .map do |note|
        {
          id: note_id_from_note(note),
          path: "#{@site.baseurl}#{note.url}#{@link_extension}",
          label: note.data['display_title'] || note.data['title'],
        }
      end

    File.write('_includes/notes-graph.json', JSON.dump({
      edges: dedupe_edges(@graph_edges),
      nodes: graph_nodes + @ghost_nodes.values,
    }))
  end

  # Collapse the directed link list into one edge per unordered pair. A pair
  # linked from both sides (A links to B *and* B links to A) is flagged
  # bidirectional so the graph can draw it with a thicker line; without this
  # such pairs would otherwise render as two overlapping lines. Ghost links
  # are one-directional by nature and are never bidirectional.
  def dedupe_edges(edges)
    directed = {}
    edges.each { |e| directed["#{e[:source]}\x00#{e[:target]}"] = true }

    collapsed = {}
    edges.each do |e|
      key = [e[:source], e[:target]].minmax
      next if collapsed.key?(key)

      reverse = directed["#{e[:target]}\x00#{e[:source]}"]
      collapsed[key] = {
        source: e[:source],
        target: e[:target],
        bidirectional: !reverse.nil?,
      }
    end
    collapsed.values
  end

  def note_id_from_note(note)
    note.data['title'].bytes.join
  end
end
