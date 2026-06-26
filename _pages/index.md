---
layout: page
title: Home
id: home
permalink: /
---

# Welcome! 🌌

<blockquote class="main-quote">
  <p>
    A historian who takes [causation] as his point of departure stops telling
    the sequence of events like the beads of a rosary. Instead, he grasps the
    <em>constellation</em> which his own era has formed with a definite earlier one.
  </p>
  <cite>— Walter Benjamin, <em>Theses on the Philosophy of History</em></cite>
</blockquote>

This site is an [[about|experiment]] in thinking.

I use this public notebook to gather fragments, concepts, readings, and questions into shifting *constellations*, as Benjamin writes. By linking texts across time and space — political theory, philosophy, literature, and whatever else happens to draw my attention — I hope to trace connections between ideas and invite you to think alongside me as they take shape.

Begin with recently-updated notes below, start with [[the canon]], or view a <a href="#" id="random-note-link" class="internal-link">random note</a>.

<hr>

## Recent Notes

<div class="recent-notes">
  {% assign recent_notes = site.notes | sort: "last_modified_at_timestamp" | reverse %}
  {% for note in recent_notes limit: 12 %}
    <div class="recent-note">
      <span class="recent-note-date">{{ note.last_modified_at | date: "%Y" }} · {{ note.last_modified_at | date: "%m" }} · {{ note.last_modified_at | date: "%d" }}</span>
      <a class="internal-link" href="{{ site.baseurl }}{{ note.url }}">{{ note.display_title | default: note.title }}</a>
    </div>
  {% endfor %}
</div>

<script>
  (function () {
    var noteUrls = [
      {% for note in site.notes %}"{{ site.baseurl }}{{ note.url }}"{% unless forloop.last %},{% endunless %}{% endfor %}
    ];
    var link = document.getElementById('random-note-link');
    link.addEventListener('click', function (e) {
      e.preventDefault();
      if (noteUrls.length === 0) return;
      window.location.href = noteUrls[Math.floor(Math.random() * noteUrls.length)];
    });
  })();
</script>
