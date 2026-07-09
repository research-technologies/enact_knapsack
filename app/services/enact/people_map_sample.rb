# frozen_string_literal: true

module Enact
  # Illustrative fallback data for the people map, lifted verbatim from the
  # design prototype (claude.ai artifact aff512de) that Nick and the team are
  # reacting to. Used only when a tenant's real contributor network is too sparse
  # to be worth drawing (see {Enact::PeopleMapController}); the page shows an
  # "illustrative data" banner in that case so no one mistakes it for real
  # records. Same JSON shape as {Enact::PeopleGraph::Result#as_json}, so the
  # client is identical either way.
  #
  # Plausible-but-invented: a mixed Westminster / Leeds / QMUL / Glasgow network
  # around a handful of practice-research outputs. Delete this once real content
  # is ingested on the tenants we demo.
  module PeopleMapSample
    module_function

    # @return [Hash] institutions/nodes/links/works_total, matching the graph
    #   service. Parsed once and frozen.
    def data
      @data ||= JSON.parse(RAW, symbolize_names: true).merge(truncated: false).freeze
    end

    RAW = <<~JSON
      {
        "institutions": [
          {"key": "Westminster", "label": "University of Westminster", "color": "#6aa9e0"},
          {"key": "Leeds", "label": "University of Leeds", "color": "#d2b94e"},
          {"key": "QMUL", "label": "Queen Mary University of London", "color": "#c074d0"},
          {"key": "GSA", "label": "Glasgow School of Art", "color": "#56b6b6"},
          {"key": "Dalry", "label": "Dalry Primary School", "color": "#7bc95a"},
          {"key": "Indep", "label": "Independent / studio", "color": "#d39a52"}
        ],
        "nodes": [
          {"id": "mclean", "label": "Bruce McLean", "inst": "Indep", "instLabel": "Independent / studio", "instColor": "#d39a52", "agent_type": "person", "orcid": "0000-0002-1825-0097", "roles": ["Conceptualization", "Artist"], "works": 8},
          {"id": "nguyen", "label": "Rosa Nguyen", "inst": "Westminster", "instLabel": "University of Westminster", "instColor": "#6aa9e0", "agent_type": "person", "orcid": "0000-0001-5109-3700", "roles": ["Project administration", "Supervision"], "works": 3},
          {"id": "sinclair", "label": "Iain Sinclair", "inst": "Westminster", "instLabel": "University of Westminster", "instColor": "#6aa9e0", "agent_type": "person", "orcid": null, "roles": ["Writing – original draft"], "works": 2},
          {"id": "raman", "label": "Priya Raman", "inst": "Leeds", "instLabel": "University of Leeds", "instColor": "#d2b94e", "agent_type": "person", "orcid": "0000-0002-7183-4990", "roles": ["Data curation"], "works": 2},
          {"id": "ferreira", "label": "Tomás Ferreira", "inst": "GSA", "instLabel": "Glasgow School of Art", "instColor": "#56b6b6", "agent_type": "person", "orcid": "0000-0003-4832-1201", "roles": ["Visualization", "Resources"], "works": 3},
          {"id": "osgood", "label": "Jayne Osgood", "inst": "QMUL", "instLabel": "Queen Mary University of London", "instColor": "#c074d0", "agent_type": "person", "orcid": "0000-0001-6098-9401", "roles": ["Writing – review & editing"], "works": 2},
          {"id": "kowalski", "label": "Maria Kowalski", "inst": "Leeds", "instLabel": "University of Leeds", "instColor": "#d2b94e", "agent_type": "person", "orcid": null, "roles": ["Investigation"], "works": 2},
          {"id": "okonkwo", "label": "Sam Okonkwo", "inst": "GSA", "instLabel": "Glasgow School of Art", "instColor": "#56b6b6", "agent_type": "person", "orcid": "0000-0002-9931-7702", "roles": ["Software"], "works": 2},
          {"id": "petrova", "label": "Elena Petrova", "inst": "Westminster", "instLabel": "University of Westminster", "instColor": "#6aa9e0", "agent_type": "person", "orcid": null, "roles": ["Methodology"], "works": 2},
          {"id": "hume", "label": "David Hume", "inst": "Indep", "instLabel": "Independent / studio", "instColor": "#d39a52", "agent_type": "person", "orcid": null, "roles": ["Photography"], "works": 3},
          {"id": "bello", "label": "Aisha Bello", "inst": "QMUL", "instLabel": "Queen Mary University of London", "instColor": "#c074d0", "agent_type": "person", "orcid": "0000-0001-2201-8836", "roles": ["Funding acquisition"], "works": 1},
          {"id": "lynn", "label": "Greg Lynn", "inst": "GSA", "instLabel": "Glasgow School of Art", "instColor": "#56b6b6", "agent_type": "person", "orcid": null, "roles": ["Formal analysis"], "works": 2},
          {"id": "campbell", "label": "Fiona Campbell", "inst": "Leeds", "instLabel": "University of Leeds", "instColor": "#d2b94e", "agent_type": "person", "orcid": "0000-0003-1122-9087", "roles": ["Supervision"], "works": 2},
          {"id": "dalry", "label": "Dalry Primary School", "inst": "Dalry", "instLabel": "Dalry Primary School", "instColor": "#7bc95a", "agent_type": "organization", "orcid": null, "roles": ["Host organisation"], "works": 3}
        ],
        "links": [
          {"source": "bello", "target": "kowalski", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Funding acquisition"], "target_roles": ["Investigation"]}]},
          {"source": "bello", "target": "mclean", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Funding acquisition"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "bello", "target": "nguyen", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Funding acquisition"], "target_roles": ["Project administration", "Supervision"]}]},
          {"source": "bello", "target": "okonkwo", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Funding acquisition"], "target_roles": ["Software"]}]},
          {"source": "bello", "target": "petrova", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Funding acquisition"], "target_roles": ["Methodology"]}]},
          {"source": "kowalski", "target": "mclean", "weight": 2, "works": [{"title": "A Machine for Learning", "source_roles": ["Investigation"], "target_roles": ["Artist", "Conceptualization"]}, {"title": "Dalry Primary School", "source_roles": ["Investigation"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "kowalski", "target": "nguyen", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Investigation"], "target_roles": ["Project administration", "Supervision"]}]},
          {"source": "kowalski", "target": "okonkwo", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Investigation"], "target_roles": ["Software"]}]},
          {"source": "kowalski", "target": "petrova", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Investigation"], "target_roles": ["Methodology"]}]},
          {"source": "mclean", "target": "nguyen", "weight": 2, "works": [{"title": "A Machine for Learning", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Project administration", "Supervision"]}, {"title": "The School Project", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Project administration", "Supervision"]}]},
          {"source": "mclean", "target": "okonkwo", "weight": 2, "works": [{"title": "A Machine for Learning", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Software"]}, {"title": "Pythagorean scale model", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Software"]}]},
          {"source": "mclean", "target": "petrova", "weight": 2, "works": [{"title": "A Machine for Learning", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Methodology"]}, {"title": "The School Project", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Methodology"]}]},
          {"source": "nguyen", "target": "okonkwo", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Project administration", "Supervision"], "target_roles": ["Software"]}]},
          {"source": "nguyen", "target": "petrova", "weight": 2, "works": [{"title": "A Machine for Learning", "source_roles": ["Project administration", "Supervision"], "target_roles": ["Methodology"]}, {"title": "The School Project", "source_roles": ["Project administration", "Supervision"], "target_roles": ["Methodology"]}]},
          {"source": "okonkwo", "target": "petrova", "weight": 1, "works": [{"title": "A Machine for Learning", "source_roles": ["Software"], "target_roles": ["Methodology"]}]},
          {"source": "campbell", "target": "dalry", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Supervision"], "target_roles": ["Host organisation"]}]},
          {"source": "campbell", "target": "kowalski", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Supervision"], "target_roles": ["Investigation"]}]},
          {"source": "campbell", "target": "mclean", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Supervision"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "campbell", "target": "raman", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Supervision"], "target_roles": ["Data curation"]}]},
          {"source": "dalry", "target": "kowalski", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Host organisation"], "target_roles": ["Investigation"]}]},
          {"source": "dalry", "target": "mclean", "weight": 2, "works": [{"title": "Dalry Primary School", "source_roles": ["Host organisation"], "target_roles": ["Artist", "Conceptualization"]}, {"title": "The School Project", "source_roles": ["Host organisation"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "dalry", "target": "raman", "weight": 2, "works": [{"title": "Dalry Primary School", "source_roles": ["Host organisation"], "target_roles": ["Data curation"]}, {"title": "Dalry video documentation", "source_roles": ["Host organisation"], "target_roles": ["Data curation"]}]},
          {"source": "kowalski", "target": "raman", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Investigation"], "target_roles": ["Data curation"]}]},
          {"source": "mclean", "target": "raman", "weight": 1, "works": [{"title": "Dalry Primary School", "source_roles": ["Artist", "Conceptualization"], "target_roles": ["Data curation"]}]},
          {"source": "ferreira", "target": "mclean", "weight": 3, "works": [{"title": "Pythagorean scale model", "source_roles": ["Resources", "Visualization"], "target_roles": ["Artist", "Conceptualization"]}, {"title": "Elevation drawing", "source_roles": ["Resources", "Visualization"], "target_roles": ["Artist", "Conceptualization"]}, {"title": "Pythagorean print", "source_roles": ["Resources", "Visualization"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "ferreira", "target": "okonkwo", "weight": 1, "works": [{"title": "Pythagorean scale model", "source_roles": ["Resources", "Visualization"], "target_roles": ["Software"]}]},
          {"source": "ferreira", "target": "lynn", "weight": 2, "works": [{"title": "Elevation drawing", "source_roles": ["Resources", "Visualization"], "target_roles": ["Formal analysis"]}, {"title": "Pythagorean print", "source_roles": ["Resources", "Visualization"], "target_roles": ["Formal analysis"]}]},
          {"source": "lynn", "target": "mclean", "weight": 2, "works": [{"title": "Elevation drawing", "source_roles": ["Formal analysis"], "target_roles": ["Artist", "Conceptualization"]}, {"title": "Pythagorean print", "source_roles": ["Formal analysis"], "target_roles": ["Artist", "Conceptualization"]}]},
          {"source": "dalry", "target": "nguyen", "weight": 1, "works": [{"title": "The School Project", "source_roles": ["Host organisation"], "target_roles": ["Project administration", "Supervision"]}]},
          {"source": "dalry", "target": "petrova", "weight": 1, "works": [{"title": "The School Project", "source_roles": ["Host organisation"], "target_roles": ["Methodology"]}]},
          {"source": "campbell", "target": "nguyen", "weight": 1, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Supervision"], "target_roles": ["Project administration", "Supervision"]}]},
          {"source": "campbell", "target": "osgood", "weight": 1, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Supervision"], "target_roles": ["Writing – review & editing"]}]},
          {"source": "campbell", "target": "sinclair", "weight": 1, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Supervision"], "target_roles": ["Writing – original draft"]}]},
          {"source": "nguyen", "target": "osgood", "weight": 1, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Project administration", "Supervision"], "target_roles": ["Writing – review & editing"]}]},
          {"source": "nguyen", "target": "sinclair", "weight": 1, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Project administration", "Supervision"], "target_roles": ["Writing – original draft"]}]},
          {"source": "osgood", "target": "sinclair", "weight": 2, "works": [{"title": "What Does Learning Look Like", "source_roles": ["Writing – review & editing"], "target_roles": ["Writing – original draft"]}, {"title": "Newspaper review", "source_roles": ["Writing – review & editing"], "target_roles": ["Writing – original draft"]}]},
          {"source": "hume", "target": "osgood", "weight": 1, "works": [{"title": "Newspaper review", "source_roles": ["Photography"], "target_roles": ["Writing – review & editing"]}]},
          {"source": "hume", "target": "sinclair", "weight": 1, "works": [{"title": "Newspaper review", "source_roles": ["Photography"], "target_roles": ["Writing – original draft"]}]},
          {"source": "dalry", "target": "hume", "weight": 1, "works": [{"title": "Dalry video documentation", "source_roles": ["Host organisation"], "target_roles": ["Photography"]}]},
          {"source": "hume", "target": "raman", "weight": 1, "works": [{"title": "Dalry video documentation", "source_roles": ["Photography"], "target_roles": ["Data curation"]}]},
          {"source": "hume", "target": "mclean", "weight": 1, "works": [{"title": "Dalry School Poster", "source_roles": ["Photography"], "target_roles": ["Artist", "Conceptualization"]}]}
        ],
        "works_total": 11
      }
    JSON
  end
end
