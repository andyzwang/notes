---
layout: page
title: Home
id: home
permalink: /
---

# Welcome! 📚

<blockquote class="homepage-quote">
  <p>
    A historian who takes [causation] as his point of departure stops telling
    the sequence of events like the beads of a rosary. Instead, he grasps the
    <em>constellation</em> which his own era has formed with a definite earlier one.
  </p>
  <cite>— Walter Benjamin, <em>Theses on the Philosophy of History</em></cite>
</blockquote>

This digital garden template is free, open-source, and [available on GitHub here](https://github.com/maximevaillancourt/digital-garden-jekyll-template).

The easiest way to get started is to read this [step-by-step guide explaining how to set this up from scratch](https://maximevaillancourt.com/blog/setting-up-your-own-digital-garden-with-jekyll).

<hr>

## Recent Notes

<div class="recent-notes">
  {% assign recent_notes = site.notes | sort: "last_modified_at_timestamp" | reverse %}
  {% for note in recent_notes limit: 10%}
    <div class="recent-note">
      <span class="recent-note-date">{{ note.last_modified_at | date: "%Y" }} · {{ note.last_modified_at | date: "%m" }} · {{ note.last_modified_at | date: "%d" }}</span>
      <a class="internal-link" href="{{ site.baseurl }}{{ note.url }}">{{ note.title }}</a>
    </div>
  {% endfor %}
</div>
