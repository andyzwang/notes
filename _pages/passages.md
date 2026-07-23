---
layout: page-hero
title: A collection of passages
permalink: /passages/
image: /assets/img/galerie-dorleans.jpg
image_title: Galerie d'Orléans, au Palais Royal
image_author: Philippe Benoist
image_date: c. 1840.
image_link: https://www.parismuseescollections.paris.fr/fr/musee-carnavalet/oeuvres/vues-de-paris-galerie-d-orleans-au-palais-royal#infos-principales
---

**These are some lines I always find myself returning to.**

<div class="passages-layout">
  <nav class="passages-index" aria-label="Jump to author by letter"></nav>
  <div class="passages">
{% for passage in site.data.passages %}
    {% assign filed = passage.sort | default: passage.author %}
    {% assign letter = filed | upcase | slice: 0 %}
    <section class="passage">
      <h2 class="passage-author" id="author-{{ passage.author | slugify }}" data-letter="{{ letter }}">
        {{ passage.author_link }}
      </h2>
      {%- if passage.quotes -%}
        {%- for q in passage.quotes -%}
          <div class="passage-body">
            <p class="passage-quote">{{ q.text }}</p>
            {%- if q.source -%}
              <p class="passage-source">{{ q.source_link }}{% if q.year %} · {{ q.year }}{% endif %}</p>
            {%- endif -%}
          </div>
        {%- endfor -%}
      {%- else -%}
        <div class="passage-body">
          <p class="passage-quote">{{ passage.quote }}</p>
          {%- if passage.source -%}
            <p class="passage-source">{{ passage.source_link }}{% if passage.year %} · {{ passage.year }}{% endif %}</p>
          {%- endif -%}
        </div>
      {%- endif -%}
    </section>
{% endfor %}
  </div>
</div>

<script>
  // Builds the A–Z rail from the authors on the page, links each present
  // letter to its first author, and highlights the letter of whichever author
  // is currently scrolled to the top (scroll-spy).
  (function () {
    var container = document.querySelector('.passages');
    var index = document.querySelector('.passages-index');
    if (!container || !index) return;

    var authors = Array.prototype.slice.call(container.querySelectorAll('.passage-author'));
    if (!authors.length) return;

    // First author element for each letter (rail links target these).
    var firstByLetter = {};
    authors.forEach(function (el) {
      var L = (el.dataset.letter || '').toUpperCase();
      if (L && !firstByLetter[L]) firstByLetter[L] = el;
    });

    var itemByLetter = {};
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').forEach(function (L) {
      var node;
      if (firstByLetter[L]) {
        node = document.createElement('a');
        node.href = '#' + firstByLetter[L].id;
        node.className = 'no-preview'; // no hover tooltip on same-page jumps
      } else {
        node = document.createElement('span');
        node.className = 'passages-index-empty';
      }
      node.textContent = L;
      index.appendChild(node);
      itemByLetter[L] = node;
    });

    // Scroll-spy: the current author is the last one whose top is above the
    // marker line; highlight its letter in the rail.
    var current = null;
    function update() {
      var marker = window.pageYOffset + 140;
      var activeLetter = authors[0].dataset.letter;
      authors.forEach(function (el) {
        if (el.getBoundingClientRect().top + window.pageYOffset <= marker) {
          activeLetter = el.dataset.letter;
        }
      });
      if (activeLetter !== current) {
        if (current && itemByLetter[current]) itemByLetter[current].classList.remove('current');
        current = activeLetter;
        if (itemByLetter[current]) itemByLetter[current].classList.add('current');
      }
    }

    var ticking = false;
    function onScroll() {
      if (!ticking) {
        requestAnimationFrame(function () { update(); ticking = false; });
        ticking = true;
      }
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();
  })();
</script>
