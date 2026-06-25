# frozen_string_literal: true
class BidirectionalLinksGenerator < Jekyll::Generator
  def generate(site)
    graph_nodes = []
    graph_edges = []

    all_notes = site.collections['notes'].docs
    all_pages = site.pages

    all_docs = all_notes + all_pages

    # Ghost nodes: links to notes that don't exist yet, keyed by
    # normalized name so multiple notes pointing at the same
    # not-yet-written note collapse into a single grey node.
    ghost_nodes = {}

    link_extension = !!site.config["use_html_extension"] ? '.html' : ''

    # Frontmatter fields whose wikilinks should be resolved the same way
    # as note body content (e.g. `author: "[[Homer]]"`)
    metadata_fields = ['author']

    # Convert all Wiki/Roam-style double-bracket link syntax to plain HTML
    # anchor tag elements (<a>) with "internal-link" CSS class
    all_docs.each do |current_note|
      all_docs.each do |note_potentially_linked_to|
        note_title_regexp_pattern = Regexp.escape(
          File.basename(
            note_potentially_linked_to.basename,
            File.extname(note_potentially_linked_to.basename)
          )
        ).gsub('\_', '[ _]').gsub('\-', '[ -]').capitalize

        title_from_data = note_potentially_linked_to.data['title']
        if title_from_data
          title_from_data = Regexp.escape(title_from_data)
        end

        new_href = "#{site.baseurl}#{note_potentially_linked_to.url}#{link_extension}"
        anchor_tag = "<a class='internal-link' href='#{new_href}'>\\1</a>"

        # Replace double-bracketed links with label using note title
        # [[A note about cats|this is a link to the note about cats]]
        current_note.content.gsub!(
          /\[\[#{note_title_regexp_pattern}\|(.+?)(?=\])\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links with label using note filename
        # [[cats|this is a link to the note about cats]]
        current_note.content.gsub!(
          /\[\[#{title_from_data}\|(.+?)(?=\])\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links using note title
        # [[a note about cats]]
        current_note.content.gsub!(
          /\[\[(#{title_from_data})\]\]/i,
          anchor_tag
        )

        # Replace double-bracketed links using note filename
        # [[cats]]
        current_note.content.gsub!(
          /\[\[(#{note_title_regexp_pattern})\]\]/i,
          anchor_tag
        )

        metadata_fields.each do |field|
          value = current_note.data[field]
          next unless value.is_a?(String)

          value = value.gsub(/\[\[#{note_title_regexp_pattern}\|(.+?)(?=\])\]\]/i, anchor_tag)
          value = value.gsub(/\[\[#{title_from_data}\|(.+?)(?=\])\]\]/i, anchor_tag)
          value = value.gsub(/\[\[(#{title_from_data})\]\]/i, anchor_tag)
          value = value.gsub(/\[\[(#{note_title_regexp_pattern})\]\]/i, anchor_tag)
          current_note.data[field] = value
        end
      end

      # At this point, all remaining double-bracket-wrapped words are
      # pointing to non-existing pages. Register a ghost graph node for
      # each one (notes only, not pages) before greying them out below.
      if all_notes.include?(current_note)
        current_note.content.scan(/\[\[([^\]]+)\]\]/i).flatten.each do |name|
          register_ghost_link(ghost_nodes, graph_edges, current_note, name)
        end

        metadata_fields.each do |field|
          value = current_note.data[field]
          next unless value.is_a?(String)

          value.scan(/\[\[([^\]]+)\]\]/i).flatten.each do |name|
            register_ghost_link(ghost_nodes, graph_edges, current_note, name)
          end
        end
      end

      # Turn remaining double-bracket links into disabled links by
      # greying them out and changing the cursor
      current_note.content = current_note.content.gsub(
        /\[\[([^\]]+)\]\]/i, # match on the remaining double-bracket links
        <<~HTML.delete("\n") # replace with this HTML (\\1 is what was inside the brackets)
          <span title='There is no note that matches this link.' class='invalid-link'>
            <span class='invalid-link-brackets'>[[</span>
            \\1
            <span class='invalid-link-brackets'>]]</span></span>
        HTML
      )

      metadata_fields.each do |field|
        value = current_note.data[field]
        next unless value.is_a?(String)

        current_note.data[field] = value.gsub(
          /\[\[([^\]]+)\]\]/i,
          <<~HTML.delete("\n")
            <span title='There is no note that matches this link.' class='invalid-link'>
              <span class='invalid-link-brackets'>[[</span>
              \\1
              <span class='invalid-link-brackets'>]]</span></span>
          HTML
        )
      end
    end

    # Identify note backlinks and add them to each note
    all_notes.each do |current_note|
      # Nodes: Jekyll
      notes_linking_to_current_note = all_notes.filter do |e|
        next false if e.url == current_note.url

        e.content.include?(current_note.url) || metadata_fields.any? do |field|
          e.data[field].is_a?(String) && e.data[field].include?(current_note.url)
        end
      end

      # Nodes: Graph
      graph_nodes << {
        id: note_id_from_note(current_note),
        path: "#{site.baseurl}#{current_note.url}#{link_extension}",
        label: current_note.data['display_title'] || current_note.data['title'],
      } unless current_note.path.include?('_notes/index.html')

      # Edges: Jekyll
      current_note.data['backlinks'] = notes_linking_to_current_note

      # Edges: Graph
      notes_linking_to_current_note.each do |n|
        graph_edges << {
          source: note_id_from_note(n),
          target: note_id_from_note(current_note),
        }
      end
    end

    File.write('_includes/notes_graph.json', JSON.dump({
      edges: graph_edges,
      nodes: graph_nodes + ghost_nodes.values,
    }))
  end

  def note_id_from_note(note)
    note.data['title'].bytes.join
  end

  def register_ghost_link(ghost_nodes, graph_edges, current_note, name)
    clean_name = name.strip
    return if clean_name.empty?

    key = clean_name.downcase
    ghost_nodes[key] ||= {
      id: "ghost-#{key.bytes.join}",
      path: nil,
      label: clean_name,
      ghost: true,
    }

    graph_edges << {
      source: note_id_from_note(current_note),
      target: ghost_nodes[key][:id],
    }
  end
end
