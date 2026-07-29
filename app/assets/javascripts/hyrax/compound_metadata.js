// OVERRIDE Hyrax v5.2.0 to enhance the contributor search-and-add flow (issue #138)
//   - render linked_record result rows with a detail line (formatResult) from
//     optional per-row fields (orcid/affiliation) the source may supply
//   - keep the "Add new" trigger always available (upstream hides it until a
//     search returns no results)
//   - add a fuzzy "did you mean" duplicate check before an inline create, driven
//     by the wrapper's data-similar-url; a second "Create" press is the override
// Each divergence from upstream is marked with an inline `OVERRIDE` comment;
// everything else mirrors upstream, so re-sync those parts on a Hyrax bump. The
// generic parts are intended for upstream (see the plan's Hyrax upstream note).
//
// Behavior for compound metadata fields on resource edit forms (add/remove row,
// work_or_url and linked_record select2 pickers). Event-delegated so
// dynamically-added rows need no rebinding. The sentinel guards against the IIFE
// running twice (Turbolinks re-evaluates module scripts on some navigation
// paths), which would stack duplicate listeners. Mirrors hyrax/redirects.js.
(function() {
    if (document.hyraxCompoundsBound) return;
    document.hyraxCompoundsBound = true;

    // Bind select2 to a `work_or_url` or `linked_record` sub-property. The v3
    // API (Hyrax bundles select2-rails 3.x) binds to a hidden input. A
    // work_or_url picker lets a typed external URL be selected as-is
    // (createSearchChoice); a linked_record picker resolves only to a row id, so
    // a typed value is not a valid selection — and an empty result set reveals
    // its "Add new" affordance instead.
    function bindWorkOrUrlInputs(root) {
        if (typeof jQuery === 'undefined' || !jQuery.fn.select2) return;
        jQuery(root).find('[data-hyrax-compound-work-input]').each(function() {
            var $el = jQuery(this);
            if ($el.hasClass('select2-offscreen') || $el.data('select2')) return; // already bound

            var isLinkedRecord = $el.is('[data-hyrax-linked-record-input]');
            var lastTerm = '';
            // Capture the wrapper now, before select2 restructures the DOM around
            // the input, so the no-results reveal doesn't depend on .closest()
            // still resolving after binding.
            var wrapEl = isLinkedRecord ? $el.closest('[data-hyrax-linked-record]')[0] : null;

            var options = {
                width: '100%',
                allowClear: true,
                // Per-field prompt via data-placeholder (work_or_url omits it and
                // keeps the original text).
                placeholder: $el.data('placeholder') || 'Search for a work or enter a URL',
                minimumInputLength: 2,
                // Render the current value's label (work title / record label /
                // URL) on load.
                initSelection: function(element, callback) {
                    var val = element.val();
                    if (!val) return;
                    callback({ id: val, text: element.data('label') || val });
                },
                ajax: {
                    url: $el.data('autocomplete-url'),
                    dataType: 'json',
                    quietMillis: 250,
                    data: function(term, page) { lastTerm = term; return { q: term }; },
                    results: function(data, page) {
                        // For a creatable linked_record, surface the "Add new"
                        // trigger when the search came back empty.
                        if (isLinkedRecord) toggleAddNew(wrapEl, data.length === 0, lastTerm);
                        return {
                            results: data.map(function(obj) {
                                // OVERRIDE: pass optional detail fields through to formatResult.
                                return { id: obj.id, text: [].concat(obj.label)[0],
                                         orcid: obj.orcid, affiliation: obj.affiliation };
                            })
                        };
                    }
                }
            };

            // Only work_or_url accepts a free-typed value as its selection.
            if (!isLinkedRecord) {
                options.createSearchChoice = function(term) { return { id: term, text: term }; };
            } else {
                // OVERRIDE: render a distinguishing result row — the label on the
                // first line, a muted second line from any optional detail fields
                // the source supplies (a source that returns only {id,label}
                // renders the plain label). We supply escapeMarkup ourselves, so
                // every interpolated value must be HTML-escaped here.
                options.formatResult = formatLinkedRecordResult;
                options.escapeMarkup = function(m) { return m; };
                // select2 v3 also runs the selection display through escapeMarkup, so
                // escape the selected text ourselves now that escapeMarkup is a no-op.
                options.formatSelection = function(data) { return escapeHtml(data && data.text); };
            }

            $el.select2(options);
        });
    }

    // Bind select2 to a `controlled` sub-property tagged
    // `data-hyrax-compound-controlled` (see _compound_row.html.erb). Unlike the
    // work_or_url / linked_record pickers, this binds a NATIVE <select> whose
    // full option list is already in the DOM, so select2 filters client-side —
    // no ajax. A `multiple` select becomes a tags-style multi picker; select2
    // infers `multiple` from the element.
    function bindControlledSelects(root) {
        if (typeof jQuery === 'undefined' || !jQuery.fn.select2) return;
        jQuery(root).find('[data-hyrax-compound-controlled]').each(function() {
            var $el = jQuery(this);
            if ($el.hasClass('select2-offscreen') || $el.data('select2')) return; // already bound

            $el.select2({
                width: '100%',
                // A single select carries a blank option (include_blank), so
                // allowClear gives it an "x"; a multiple has none and needs a
                // placeholder to prompt.
                allowClear: !$el.prop('multiple'),
                placeholder: $el.data('placeholder') || ''
            });
        });
    }

    // OVERRIDE: keep the "Add new" trigger available whether or not the search
    // matched (upstream shows/hides it based on the result count), so a curator
    // seeing partial/wrong matches can still create — the enriched result rows do
    // the disambiguation. The partial renders the button visible from the start;
    // this only refreshes the stashed typed term (used to prefill the create
    // form). `wrapEl` is the [data-hyrax-linked-record] wrapper captured at bind time.
    function toggleAddNew(wrapEl, _noResults, term) {
        if (!wrapEl || wrapEl.getAttribute('data-creatable') !== 'true') return;
        jQuery(wrapEl).data('lastTerm', term || '');
    }

    // OVERRIDE: helpers below (escapeHtml, formatLinkedRecordResult) are not in
    // upstream — they render the linked_record result-row detail line.
    //
    // HTML-escape a value for interpolation into a formatResult template (select2's
    // default escaping is off once we supply escapeMarkup).
    function escapeHtml(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    // Render a linked_record result row: the label on the first line, and a muted
    // second line joining whatever optional detail fields the source supplied
    // (orcid, affiliation). Falls back to the plain label when a source supplies
    // no detail, so this stays source-agnostic.
    function formatLinkedRecordResult(item) {
        var label = escapeHtml(item.text);
        var details = [item.orcid, item.affiliation]
            .filter(function(v) { return v != null && String(v).trim() !== ''; })
            .map(escapeHtml);
        if (!details.length) return label;
        // The detail color is set in CSS (not Bootstrap's .text-muted), so the
        // highlighted row can flip it to a readable color against the highlight
        // background — see _compound_metadata.scss.
        return '<div class="linked-record-option">' + label +
               '<div class="linked-record-option-detail small">' +
               details.join(' &middot; ') + '</div></div>';
    }

    // Bind saved rows once the DOM is ready (at script-eval time the form
    // inputs don't exist yet, so the select2 would never attach). Covers both a
    // fresh load and Turbolinks navigation.
    function bindAll() { bindWorkOrUrlInputs(document); bindControlledSelects(document); }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bindAll);
    } else {
        bindAll();
    }
    document.addEventListener('turbolinks:load', bindAll);

    // Reveal the inline create form (prefilling the first text field with the
    // typed search term), POST it to the source's create endpoint, and on
    // success select the new record in the picker.
    function openCreateForm(wrap) {
        if (!wrap) return;
        var form = wrap.querySelector('[data-hyrax-linked-record-create-form]');
        if (!form) return;
        form.classList.remove('d-none');
        form.hidden = false;
        var firstText = form.querySelector('input[data-create-field]');
        var term = jQuery(wrap).data('lastTerm');
        if (firstText && term && !firstText.value) firstText.value = term;
    }

    function closeCreateForm(wrap) {
        if (!wrap) return;
        var form = wrap.querySelector('[data-hyrax-linked-record-create-form]');
        if (form) {
            form.classList.add('d-none'); form.hidden = true;
            // OVERRIDE: reset the duplicate-check state so a later open starts clean.
            var panel = form.querySelector('[data-hyrax-linked-record-similar]');
            if (panel) { panel.classList.add('d-none'); panel.hidden = true; }
        }
        jQuery(wrap).data('createConfirmed', false); // OVERRIDE: clear the warned latch
    }

    // Collect the create form's inputs into the {record} payload the create
    // endpoint expects.
    function collectCreateRecord(form) {
        var record = {};
        // Scalar create-fields: one value each. Skip inputs that live inside a
        // group (those are collected per-row below).
        form.querySelectorAll('[data-create-field]').forEach(function(input) {
            if (input.closest('[data-create-group]')) return;
            record[input.getAttribute('data-create-field')] = input.value;
        });
        // Repeatable create-fields: collected from their rows (the <template>
        // row is inert). A group field becomes an array of {subfield: value}
        // hashes; a repeatable scalar (data-create-scalar) becomes a plain array
        // of strings. Blank rows are skipped.
        form.querySelectorAll('[data-create-group]').forEach(function(group) {
            var name = group.getAttribute('data-create-group');
            var scalar = group.getAttribute('data-create-scalar') === 'true';
            var rows = [];
            group.querySelectorAll('[data-create-group-rows] [data-create-group-row]').forEach(function(rowEl) {
                if (scalar) {
                    var input = rowEl.querySelector('[data-create-subfield]');
                    if (input && input.value) rows.push(input.value);
                } else {
                    var row = {};
                    var any = false;
                    rowEl.querySelectorAll('[data-create-subfield]').forEach(function(sub) {
                        row[sub.getAttribute('data-create-subfield')] = sub.value;
                        if (sub.value) any = true;
                    });
                    if (any) rows.push(row);
                }
            });
            record[name] = rows;
        });
        return record;
    }

    // The typed name for the duplicate check: the first scalar create-field (the
    // create form's leading text input, which is the display name).
    function createFormName(form) {
        var first = form.querySelector('input[data-create-field]');
        return first ? first.value : '';
    }

    // OVERRIDE: create submit gains a fuzzy "did you mean" gate — when the source
    // offers a check (data-similar-url) and the entered name has similar existing
    // records, show them and hold. A second press (createConfirmed latch) or a
    // source with no similar-url creates immediately. Upstream posts directly.
    // The similar-check functions below (checkSimilarThenCreate, showSimilar,
    // selectRecord) and the input listener are not in upstream; postCreate /
    // collectCreateRecord / createFormName are extracted from upstream's inline body.
    function submitCreateForm(wrap) {
        if (!wrap) return;
        var form = wrap.querySelector('[data-hyrax-linked-record-create-form]');
        if (!form) return;

        var similarUrl = wrap.getAttribute('data-similar-url');
        if (similarUrl && !jQuery(wrap).data('createConfirmed')) {
            checkSimilarThenCreate(wrap, form, similarUrl);
            return;
        }
        postCreate(wrap, form);
    }

    // Fetch similar records for the typed name; if any, render the warning panel
    // and hold. If none (or the check fails), fall through to creating.
    function checkSimilarThenCreate(wrap, form, similarUrl) {
        var name = createFormName(form).trim();
        if (!name) { postCreate(wrap, form); return; }

        var sep = similarUrl.indexOf('?') === -1 ? '?' : '&';
        fetch(similarUrl + sep + 'q=' + encodeURIComponent(name), {
            headers: { 'Accept': 'application/json' }, credentials: 'same-origin'
        }).then(function(resp) {
            return resp.ok ? resp.json() : [];
        }).catch(function() {
            return [];
        }).then(function(candidates) {
            if (candidates && candidates.length) {
                showSimilar(wrap, form, candidates);
            } else {
                // Nothing similar — create without a further click.
                postCreate(wrap, form);
            }
        });
    }

    // Render the fuzzy-match warning panel: one "Use this" row per candidate.
    // Selecting a candidate reuses the existing record; the primary "Create"
    // button becomes the override — set the latch so the *next* Create press
    // skips the check and creates. Editing the name clears the latch (see the
    // create-form input listener) so a changed name is re-checked.
    function showSimilar(wrap, form, candidates) {
        var panel = form.querySelector('[data-hyrax-linked-record-similar]');
        var list = form.querySelector('[data-hyrax-linked-record-similar-list]');
        if (!panel || !list) { postCreate(wrap, form); return; }

        list.innerHTML = '';
        candidates.forEach(function(c) {
            var detail = [c.orcid, c.affiliation]
                .filter(function(v) { return v != null && String(v).trim() !== ''; })
                .map(escapeHtml).join(' &middot; ');
            var li = document.createElement('li');
            li.className = 'd-flex align-items-center justify-content-between mb-1';
            li.innerHTML = '<span>' + escapeHtml(c.label) +
                (detail ? ' <span class="text-muted small">' + detail + '</span>' : '') + '</span>';
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn btn-link btn-sm p-0 ml-2 text-nowrap';
            btn.setAttribute('data-hyrax-linked-record-use', '');
            btn.setAttribute('data-id', c.id);
            btn.setAttribute('data-label', c.label);
            btn.textContent = list.getAttribute('data-use-label') || 'Use this';
            li.appendChild(btn);
            list.appendChild(li);
        });
        panel.classList.remove('d-none');
        panel.hidden = false;
        // Warned once: the next "Create" press proceeds instead of re-checking.
        jQuery(wrap).data('createConfirmed', true);
    }

    // POST the collected record to the create endpoint; on success select the new
    // record in the picker.
    function postCreate(wrap, form) {
        var url = wrap.getAttribute('data-create-url');
        if (!url) return;
        var errors = form.querySelector('[data-hyrax-linked-record-create-errors]');
        var record = collectCreateRecord(form);

        // Show server-supplied messages (already localized), falling back to the
        // localized default the partial set on `data-default-message`.
        function showError(messages) {
            if (!errors) return;
            var fallback = errors.getAttribute('data-default-message') || 'Could not create';
            var list = [].concat(messages || []).filter(Boolean);
            errors.textContent = (list.length ? list : [fallback]).join(', ');
            errors.classList.remove('d-none');
        }

        var token = (document.querySelector('meta[name="csrf-token"]') || {}).content;
        fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token || '', 'Accept': 'application/json' },
            body: JSON.stringify({ record: record })
        }).then(function(resp) {
            // A 5xx (e.g. a DB-level failure) returns an HTML error page, not
            // JSON; tolerate a non-JSON body so the form still surfaces a message
            // instead of silently swallowing the parse error.
            return resp.text().then(function(text) {
                var body;
                try { body = JSON.parse(text); } catch (e) { body = {}; }
                return { ok: resp.ok, body: body };
            });
        }).then(function(result) {
            if (result.ok) {
                // Select the new record in the picker (select2 v3 takes {id,text}).
                selectRecord(wrap, result.body.id, result.body.label);
                closeCreateForm(wrap);
            } else {
                showError(result.body.errors);
            }
        }).catch(function() {
            // No-arg showError falls back to the localized default message.
            showError();
        });
    }

    // Select an existing/new record in the picker and reset the create-confirm
    // latch so a later create re-runs the duplicate check.
    function selectRecord(wrap, id, label) {
        jQuery(wrap).find('[data-hyrax-linked-record-input]')
            .select2('data', { id: id, text: label });
        jQuery(wrap).data('createConfirmed', false);
    }

    // OVERRIDE: editing any create-form field after a duplicate warning clears the
    // "warned" latch and hides the panel, so the next "Create" re-checks the
    // (possibly changed) name rather than creating straight through. Not in upstream.
    document.addEventListener('input', function(event) {
        if (!event.target.closest('[data-hyrax-linked-record-create-form]')) return;
        var wrap = event.target.closest('[data-hyrax-linked-record]');
        if (!wrap || !jQuery(wrap).data('createConfirmed')) return;
        jQuery(wrap).data('createConfirmed', false);
        var panel = wrap.querySelector('[data-hyrax-linked-record-similar]');
        if (panel) { panel.classList.add('d-none'); panel.hidden = true; }
    });

    document.addEventListener('click', function(event) {
        // --- linked_record inline create affordance ---
        var addTrigger = event.target.closest('[data-hyrax-linked-record-add]');
        if (addTrigger) {
            openCreateForm(addTrigger.closest('[data-hyrax-linked-record]'));
            return;
        }
        var createSubmit = event.target.closest('[data-hyrax-linked-record-create-submit]');
        if (createSubmit) {
            submitCreateForm(createSubmit.closest('[data-hyrax-linked-record]'));
            return;
        }
        // OVERRIDE: "Use this" on a fuzzy-match candidate reuses the existing
        // record instead of creating a duplicate. Not in upstream.
        var useTrigger = event.target.closest('[data-hyrax-linked-record-use]');
        if (useTrigger) {
            var useWrap = useTrigger.closest('[data-hyrax-linked-record]');
            selectRecord(useWrap, useTrigger.getAttribute('data-id'), useTrigger.getAttribute('data-label'));
            closeCreateForm(useWrap);
            return;
        }
        var createCancel = event.target.closest('[data-hyrax-linked-record-create-cancel]');
        if (createCancel) {
            closeCreateForm(createCancel.closest('[data-hyrax-linked-record]'));
            return;
        }
        // Repeatable group create-field: add a row (clone the template) / remove a row.
        var groupAdd = event.target.closest('[data-create-group-add]');
        if (groupAdd) {
            var group = groupAdd.closest('[data-create-group]');
            var template = group.querySelector('[data-create-group-row-template]');
            var rows = group.querySelector('[data-create-group-rows]');
            if (template && rows) rows.appendChild(template.content.cloneNode(true));
            return;
        }
        var groupRemove = event.target.closest('[data-create-group-remove]');
        if (groupRemove) {
            var groupRows = groupRemove.closest('[data-create-group-rows]');
            var thisRow = groupRemove.closest('[data-create-group-row]');
            // Keep at least one row present; clear it instead of removing the last.
            if (groupRows && groupRows.querySelectorAll('[data-create-group-row]').length > 1) {
                thisRow.parentNode.removeChild(thisRow);
            } else if (thisRow) {
                thisRow.querySelectorAll('[data-create-subfield]').forEach(function(i) { i.value = ''; });
            }
            return;
        }

        var removeButton = event.target.closest('[data-hyrax-compound-remove-row]');
        if (removeButton) {
            var row = removeButton.closest('[data-hyrax-compound-row]');
            if (!row) return;
            var destroyFlag = row.querySelector('[data-hyrax-compound-destroy-flag]');
            if (destroyFlag && destroyFlag.value !== undefined) {
                // Persisted rows: flip the _destroy flag and hide so the
                // populator drops the row server-side.
                destroyFlag.value = '1';
                row.style.display = 'none';
            } else {
                row.parentNode.removeChild(row);
            }
            return;
        }

        var addButton = event.target.closest('[data-hyrax-compound-add-row]');
        if (!addButton) return;
        var section = addButton.closest('[data-hyrax-compound]');
        if (!section) return;
        var template = section.querySelector('[data-hyrax-compound-row-template]');
        var rowsHost = section.querySelector('[data-hyrax-compound-rows]');
        if (!template || !rowsHost) return;

        // Monotonic counter on the section; never recycle an index after a
        // row is removed. Fallback to row count when the attribute is missing.
        var nextIndex = parseInt(section.dataset.nextIndex, 10);
        if (isNaN(nextIndex)) {
            nextIndex = rowsHost.querySelectorAll('[data-hyrax-compound-row]').length;
        }
        var html = template.innerHTML.replace(/__INDEX__/g, nextIndex);
        rowsHost.insertAdjacentHTML('beforeend', html);
        // Bind select2 on any work_or_url / linked_record inputs and controlled
        // typeahead selects in the new row.
        bindWorkOrUrlInputs(rowsHost.lastElementChild || rowsHost);
        bindControlledSelects(rowsHost.lastElementChild || rowsHost);
        section.dataset.nextIndex = String(nextIndex + 1);
    });
})();
