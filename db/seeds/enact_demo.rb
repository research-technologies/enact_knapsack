# frozen_string_literal: true

# Seed the Enact pathfinder demo: one Portfolio with four typed PortfolioItem
# children (Artefact / Event / Literature / Collection), each with an image
# file, full compound metadata, public visibility, ingested + characterised
# + with derivatives generated. The Portfolio's representative_id/thumbnail_id
# point at the first child's FileSet so Universal Viewer bootstraps and shows
# every child as a canvas via the aggregated IIIF manifest.
#
# Run inside the web container against the dev tenant:
#
#   docker exec -i enact_knapsack-web-1 sh -c \
#     'cd /app/samvera/hyrax-webapp && bundle exec rails runner /app/samvera/db/seeds/enact_demo.rb'
#
# Requires four placeholder PNGs at /tmp/enact_seed/{artefact-score,event-exhibition,
# literature-article,collection-sketchbook}.png. Generate them with ImageMagick
# inside the container - see the seed README for the commands.
#
# To wipe first, run /app/samvera/db/seeds/enact_demo_wipe.rb.

require 'shellwords'

AccountElevator.switch!(ENV.fetch('ENACT_DEMO_TENANT', 'dev-enact-knapsack.localhost.direct'))

ADMIN = User.find_by!(email: ENV.fetch('ENACT_DEMO_ADMIN_EMAIL', 'admin@example.com'))
ADMIN_SET_ID = Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
SEED_DIR = ENV.fetch('ENACT_DEMO_FILES_DIR', '/tmp/enact_seed')

def make_public!(work)
  # work.visibility= only mutates the in-memory PermissionManager ACL; we
  # have to acl.save before the change is durable, then re-index so Solr
  # picks up read_groups=['public'].
  Hyrax::VisibilityWriter.new(resource: work).assign_access_for(visibility: 'open')
  work.permission_manager.acl.save
end

def create_work(klass, scalars:, compounds:)
  work = klass.new(scalars.merge(compounds))
  work.depositor = ADMIN.user_key
  work.admin_set_id = Valkyrie::ID.new(ADMIN_SET_ID)
  work = Hyrax.persister.save(resource: work)
  make_public!(work)
  Hyrax.index_adapter.save(resource: work)
  work
end

def attach_file!(work, file_path)
  uploaded = Hyrax::UploadedFile.create!(user: ADMIN, file: File.open(file_path))
  Hyrax::WorkUploadsHandler.new(work:).add(files: [uploaded]).attach
  # The actor stack enqueues ingest + characterise + derivative jobs; in the
  # seed context the worker may not be running, so drive them synchronously.
  ValkyrieIngestJob.perform_now(uploaded)

  work = Hyrax.query_service.find_by(id: work.id)
  fs_id = work.member_ids.last
  return unless fs_id

  fs = Hyrax.query_service.find_by(id: fs_id)
  make_public!(fs)
  files = Hyrax.custom_queries.find_files(file_set: fs).to_a
  fm = files.find(&:original_file?) || files.first
  return unless fm

  # Characterise + force PNG mime + read real dimensions via ImageMagick, so
  # the IIIF manifest builder and FileSet derivative service have what they
  # need. FITS is unreliable in dev containers; identify -format is solid.
  CharacterizeJob.perform_now(fm, fm.file_identifier.to_s)
  fm = Hyrax.query_service.find_by(id: fm.id)
  dims = `identify -format '%w %h' #{file_path.shellescape} 2>/dev/null`.strip
  if dims.match?(/\A\d+ \d+\z/)
    w, h = dims.split.map(&:to_i)
    fm.width = [w]
    fm.height = [h]
  end
  fm.mime_type = 'image/png' if fm.mime_type.to_s.empty? || fm.mime_type == 'application/octet-stream'
  Hyrax.persister.save(resource: fm)

  ValkyrieCreateDerivativesJob.perform_now(fs.id.to_s, fm.id.to_s)
  Hyrax.index_adapter.save(resource: fs)
end

PORTFOLIO_SCALARS = {
  title: ['Portfolio: Bonfire of the Manuscripts'],
  description: 'A practice-research portfolio exploring erasure as a compositional method - across score, exhibition, journal, and curated workbook outputs.',
  context_statement: 'Submitted as a REF 2029 unit-of-assessment portfolio, demonstrating outputs across composition, performance, and curatorial practice.',
  date_created: '2024-01-15',
  date_made_public: '2025-03-01',
  date_range_of_outputs: '2023-09 / 2025-02',
  publisher: ['University of Westminster'],
  portfolio_identifier: 'raid:placeholder-bonfire-2025',
  keyword: %w[erasure practice-research composition exhibition],
  research_group: ['Centre for Research in Music and Sound'],
  rights_statement: 'Metadata is licensed under Creative Commons Zero (CC0 1.0).',
  file_access_level: 'open',
  ref_unit_of_assessment: '33 - Music, Drama, Dance, Performing Arts, Film and Screen Studies'
}.freeze

PORTFOLIO_COMPOUNDS = {
  titles: [
    { 'value' => 'Portfolio: Bonfire of the Manuscripts', 'title_type' => '', 'lang' => 'en' },
    { 'value' => 'Bonfire der Manuskripte (Werkzyklus)', 'title_type' => 'TranslatedTitle', 'lang' => 'de' }
  ],
  dates: [
    { 'value' => '2024-01-15', 'date_type' => 'Created', 'date_information' => 'composition begun' },
    { 'value' => '2025-02-20', 'date_type' => 'Issued', 'date_information' => 'portfolio finalised' }
  ],
  contributors: [
    { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
      'name_type' => 'Personal', 'role_label' => 'composer', 'role_id' => 'cmp',
      'role_vocabulary' => 'LOC relators', 'name_identifier' => '0000-0001-2345-6789',
      'scheme_uri' => 'https://orcid.org', 'affiliation' => 'University of Westminster',
      'affiliation_identifier' => 'https://ror.org/04ycpbx82' },
    { 'given_name' => 'Imran', 'family_name' => 'Khan', 'contributor_name' => 'Imran Khan',
      'name_type' => 'Personal', 'role_label' => 'performer', 'role_id' => 'prf',
      'name_identifier' => '0000-0002-3456-7890', 'affiliation' => 'Royal Academy of Music' }
  ],
  identifiers: [
    { 'value' => 'doi:10.1234/bonfire.2025', 'identifier_type' => 'doi' },
    { 'value' => 'https://hdl.handle.net/2027/enact.bonfire', 'identifier_type' => 'handle' }
  ],
  funding_references: [
    { 'funder_name' => 'Arts and Humanities Research Council', 'funder_identifier' => 'https://ror.org/0524sp257',
      'funder_identifier_type' => 'ROR', 'award_number' => 'AH/X012345/1',
      'award_uri' => 'https://gtr.ukri.org/projects?ref=AH%2FX012345%2F1',
      'award_title' => 'Practice as Research in Composition: 2023-2026' }
  ],
  organisational_units: [
    { 'name' => 'Centre for Research in Music and Sound', 'pid' => 'https://ror.org/04ycpbx82', 'unit_type' => 'Research Centre' },
    { 'name' => 'School of Arts', 'pid' => 'https://ror.org/04ycpbx82', 'unit_type' => 'School' }
  ],
  licenses: [
    { 'rights_label' => 'CC BY-NC-SA 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
      'rights_identifier' => 'CC-BY-NC-SA-4.0', 'rights_identifier_scheme' => 'SPDX',
      'scheme_uri' => 'https://spdx.org/licenses/', 'lang' => 'en', 'holder' => 'Avery Brooks' },
    { 'rights_label' => 'Performance rights reserved', 'holder' => 'PRS for Music' }
  ]
}.freeze

CHILDREN = [
  {
    file: File.join(SEED_DIR, 'artefact-score.png'),
    scalars: {
      title: ['Lacrimae Rerum (full score)'],
      description: 'Through-composed piece for prepared piano and string quartet, 14 minutes.',
      context_statement: 'Premiered at the Wigmore Hall in October 2024 as part of the broader Bonfire portfolio.',
      date_created: '2024-03-12',
      date_made_public: '2024-10-08',
      portfolio_item_type: 'Artefact',
      item_subtype: 'composition',
      media_type: 'score',
      file_access_level: 'open'
    },
    compounds: {
      titles: [
        { 'value' => 'Lacrimae Rerum (full score)', 'title_type' => '', 'lang' => 'en' },
        { 'value' => 'Lacrimae Rerum (parts)', 'title_type' => 'AlternativeTitle', 'lang' => 'en' }
      ],
      dates: [
        { 'value' => '2024-03-12', 'date_type' => 'Created', 'date_information' => 'composition completed' },
        { 'value' => '2024-10-08', 'date_type' => 'Issued', 'date_information' => 'world premiere' }
      ],
      contributors: [
        { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
          'name_type' => 'Personal', 'role_label' => 'composer',
          'name_identifier' => '0000-0001-2345-6789', 'affiliation' => 'University of Westminster' }
      ],
      identifiers: [{ 'value' => 'doi:10.1234/bonfire.lacrimae.score', 'identifier_type' => 'doi' }],
      licenses: [{ 'rights_label' => 'CC BY-NC 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc/4.0/' }],
      geo_locations: []
    }
  },
  {
    file: File.join(SEED_DIR, 'event-exhibition.png'),
    scalars: {
      title: ['Three Performances of Erasure'],
      description: 'A three-night exhibition at Tate Modern presenting Lacrimae Rerum alongside two new commissions.',
      context_statement: 'Curated by the artist with audio-visual installation by Imran Khan; documentation under separate copyright.',
      date_created: '2024-08-22',
      date_made_public: '2024-08-22',
      portfolio_item_type: 'Event',
      item_subtype: 'exhibition',
      media_type: 'event',
      file_access_level: 'open'
    },
    compounds: {
      titles: [{ 'value' => 'Three Performances of Erasure', 'lang' => 'en' }],
      dates: [{ 'value' => '2024-08-22/2024-08-24', 'date_type' => 'EventDateRange', 'date_information' => 'three-night run' }],
      contributors: [
        { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
          'role_label' => 'curator', 'name_identifier' => '0000-0001-2345-6789' },
        { 'given_name' => 'Imran', 'family_name' => 'Khan', 'contributor_name' => 'Imran Khan',
          'role_label' => 'sound designer', 'name_identifier' => '0000-0002-3456-7890' }
      ],
      identifiers: [{ 'value' => 'https://tate.org.uk/whats-on/erasure-2024', 'identifier_type' => 'url' }],
      licenses: [{ 'rights_label' => 'All rights reserved (event documentation)' }],
      geo_locations: [
        { 'place_name' => 'Tate Modern', 'point_latitude' => '51.5076', 'point_longitude' => '-0.0994' }
      ]
    }
  },
  {
    file: File.join(SEED_DIR, 'literature-article.png'),
    scalars: {
      title: ['Notes on Erasure as Compositional Method'],
      description: 'A peer-reviewed journal article reflecting on the compositional process underlying Lacrimae Rerum.',
      context_statement: 'Published in Practice as Research in Music & Sound, volume 12, issue 2.',
      date_created: '2024-11-04',
      date_made_public: '2025-01-15',
      portfolio_item_type: 'Literature',
      item_subtype: 'article',
      media_type: 'article',
      file_access_level: 'open',
      place_of_publication: 'London, United Kingdom'
    },
    compounds: {
      titles: [{ 'value' => 'Notes on Erasure as Compositional Method', 'lang' => 'en' }],
      dates: [{ 'value' => '2025-01-15', 'date_type' => 'Issued', 'date_information' => 'journal publication' }],
      contributors: [
        { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
          'role_label' => 'author', 'name_identifier' => '0000-0001-2345-6789' }
      ],
      identifiers: [{ 'value' => 'doi:10.5678/parims.2025.0042', 'identifier_type' => 'doi' }],
      licenses: [{ 'rights_label' => 'CC BY 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by/4.0/' }]
    }
  },
  {
    file: File.join(SEED_DIR, 'collection-sketchbook.png'),
    scalars: {
      title: ['Workbook & Sketchbooks 2024-2025'],
      description: 'A curated set of sketches, notes, and process documentation spanning the Bonfire portfolio.',
      context_statement: 'Selected and ordered by the artist; original notebooks held in the personal archive.',
      date_created: '2024-01-01',
      date_made_public: '2025-02-20',
      portfolio_item_type: 'Collection',
      item_subtype: 'curated_set',
      media_type: 'mixed',
      file_access_level: 'open',
      extent: '47 items',
      extent_type: 'items',
      collection_order: 'chronological'
    },
    compounds: {
      titles: [{ 'value' => 'Workbook & Sketchbooks 2024-2025', 'lang' => 'en' }],
      dates: [{ 'value' => '2024-01-01/2025-02-20', 'date_type' => 'DateRange', 'date_information' => 'sketch period' }],
      contributors: [
        { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
          'role_label' => 'creator', 'name_identifier' => '0000-0001-2345-6789' }
      ],
      identifiers: [{ 'value' => 'doi:10.1234/bonfire.workbook', 'identifier_type' => 'doi' }],
      licenses: [{ 'rights_label' => 'CC BY-NC 4.0' }]
    }
  }
].freeze

puts "Admin set: #{ADMIN_SET_ID}"
puts "\n== Portfolio =="
portfolio = create_work(Portfolio, scalars: PORTFOLIO_SCALARS, compounds: PORTFOLIO_COMPOUNDS)
puts "  -> Portfolio #{portfolio.id} created"

child_ids = []
CHILDREN.each do |spec|
  puts "\n== PortfolioItem: #{spec[:scalars][:title].first} =="
  child = create_work(PortfolioItem, scalars: spec[:scalars], compounds: spec[:compounds])
  puts "  -> Item #{child.id} (#{spec[:scalars][:portfolio_item_type]} / #{spec[:scalars][:item_subtype]})"
  attach_file!(child, spec[:file]) if File.exist?(spec[:file])
  child_ids << child.id.to_s
end

puts "\n== Wiring child membership + UV representative =="
portfolio = Hyrax.query_service.find_by(id: portfolio.id)
portfolio.member_ids = child_ids.map { |id| Valkyrie::ID.new(id) }

# UV's bootstrap gate in `_representative_media.html.erb` requires
# representative_id to resolve. The Portfolio has no direct file_set, so
# borrow the first child's representative FileSet. The Portfolio's IIIF
# manifest already aggregates every descendant FileSet, so UV will show
# all four children once it loads.
first_child = Hyrax.query_service.find_by(id: child_ids.first)
fs_id = first_child.representative_id || first_child.thumbnail_id || first_child.member_ids.first
if fs_id
  portfolio.representative_id = fs_id
  portfolio.thumbnail_id      = fs_id
end

portfolio = Hyrax.persister.save(resource: portfolio)
Hyrax.index_adapter.save(resource: portfolio)
child_ids.each { |id| Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id:)) }
Hyrax::SolrService.commit

puts "\nDone. Portfolio has #{portfolio.member_ids.size} member(s)."
puts "View at https://#{ENV.fetch('ENACT_DEMO_TENANT', 'dev-enact-knapsack.localhost.direct')}/concern/portfolios/#{portfolio.id}"
