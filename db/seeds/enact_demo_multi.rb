# frozen_string_literal: true

# Multi-portfolio Enact demo seed. Creates four Portfolios spanning music
# composition, visual art, theatre, and dance, each with four typed
# PortfolioItem children (Artefact / Event / Literature / Collection) and
# an image file. All works are made public, UV is wired at the Portfolio
# level via representative_id/thumbnail_id pointing at the first child's
# FileSet.
#
# Run inside the staging pod against the demo tenant:
#
#   kubectl exec -n enact-knapsack-staging deploy/enact-knapsack-staging -c hyrax -- \
#     sh -c 'cd /app/samvera/hyrax-webapp && \
#            ENACT_DEMO_TENANT=demo.enact-knapsack-staging.enacthyku.com \
#            bundle exec rails runner /app/samvera/db/seeds/enact_demo_multi.rb'
#
# Requires sixteen 1200x800 PNGs in $ENACT_DEMO_FILES_DIR (default /tmp/enact_seed).
# See db/seeds/README.md for ImageMagick generation commands.

require 'shellwords'

AccountElevator.switch!(ENV.fetch('ENACT_DEMO_TENANT', 'demo.enact-knapsack-staging.enacthyku.com'))

ADMIN = User.find_by!(email: ENV.fetch('ENACT_DEMO_ADMIN_EMAIL', 'admin@example.com'))
ADMIN_SET_ID = Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
SEED_DIR = ENV.fetch('ENACT_DEMO_FILES_DIR', '/tmp/enact_seed')

def make_public!(work)
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
  ValkyrieIngestJob.perform_now(uploaded)

  work = Hyrax.query_service.find_by(id: work.id)
  fs_id = work.member_ids.last
  return unless fs_id

  fs = Hyrax.query_service.find_by(id: fs_id)
  make_public!(fs)
  files = Hyrax.custom_queries.find_files(file_set: fs).to_a
  fm = files.find(&:original_file?) || files.first
  return unless fm

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

# rubocop:disable Metrics/CollectionLiteralLength
PORTFOLIOS = [
  {
    portfolio: {
      scalars: {
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
      },
      compounds: {
        titles: [
          { 'value' => 'Portfolio: Bonfire of the Manuscripts', 'title_type' => '', 'lang' => 'en' }
        ],
        dates: [
          { 'value' => '2024-01-15', 'date_type' => 'Created', 'date_information' => 'composition begun' },
          { 'value' => '2025-02-20', 'date_type' => 'Issued', 'date_information' => 'portfolio finalised' }
        ],
        contributors: [
          { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks',
            'name_type' => 'Personal', 'role_label' => 'composer', 'role_id' => 'cmp',
            'name_identifier' => '0000-0001-2345-6789', 'scheme_uri' => 'https://orcid.org',
            'affiliation' => 'University of Westminster', 'affiliation_identifier' => 'https://ror.org/04ycpbx82' }
        ],
        identifiers: [
          { 'value' => 'doi:10.1234/bonfire.2025', 'identifier_type' => 'doi' }
        ],
        funding_references: [
          { 'funder_name' => 'Arts and Humanities Research Council', 'funder_identifier' => 'https://ror.org/0524sp257',
            'funder_identifier_type' => 'ROR', 'award_number' => 'AH/X012345/1',
            'award_title' => 'Practice as Research in Composition: 2023-2026' }
        ],
        organisational_units: [
          { 'name' => 'Centre for Research in Music and Sound', 'pid' => 'https://ror.org/04ycpbx82', 'unit_type' => 'Research Centre' }
        ],
        licenses: [
          { 'rights_label' => 'CC BY-NC-SA 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
            'rights_identifier' => 'CC-BY-NC-SA-4.0', 'rights_identifier_scheme' => 'SPDX', 'holder' => 'Avery Brooks' }
        ]
      }
    },
    children: [
      { file: 'bonfire-artefact.png',
        scalars: { title: ['Lacrimae Rerum (full score)'],
                   description: 'Through-composed piece for prepared piano and string quartet, 14 minutes.',
                   context_statement: 'Premiered at the Wigmore Hall in October 2024.',
                   date_created: '2024-03-12', date_made_public: '2024-10-08',
                   portfolio_item_type: 'Artefact', item_subtype: 'composition',
                   media_type: 'score', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Lacrimae Rerum (full score)', 'lang' => 'en' }],
                     dates: [{ 'value' => '2024-10-08', 'date_type' => 'Issued', 'date_information' => 'world premiere' }],
                     contributors: [{ 'contributor_name' => 'Avery Brooks', 'role_label' => 'composer',
                                      'name_identifier' => '0000-0001-2345-6789' }],
                     licenses: [{ 'rights_label' => 'CC BY-NC 4.0' }] } },
      { file: 'bonfire-event.png',
        scalars: { title: ['Three Performances of Erasure'],
                   description: 'A three-night exhibition at Tate Modern presenting Lacrimae Rerum alongside two new commissions.',
                   context_statement: 'Curated by the artist with audio-visual installation by Imran Khan.',
                   date_created: '2024-08-22', date_made_public: '2024-08-22',
                   portfolio_item_type: 'Event', item_subtype: 'exhibition',
                   media_type: 'event', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Three Performances of Erasure', 'lang' => 'en' }],
                     dates: [{ 'value' => '2024-08-22/2024-08-24', 'date_type' => 'EventDateRange' }],
                     contributors: [{ 'contributor_name' => 'Avery Brooks', 'role_label' => 'curator' },
                                    { 'contributor_name' => 'Imran Khan', 'role_label' => 'sound designer' }],
                     geo_locations: [{ 'place_name' => 'Tate Modern, London',
                                       'point_latitude' => '51.5076', 'point_longitude' => '-0.0994' }] } },
      { file: 'bonfire-literature.png',
        scalars: { title: ['Notes on Erasure as Compositional Method'],
                   description: 'A peer-reviewed journal article reflecting on the compositional process underlying Lacrimae Rerum.',
                   context_statement: 'Published in Practice as Research in Music & Sound, volume 12, issue 2.',
                   date_created: '2024-11-04', date_made_public: '2025-01-15',
                   portfolio_item_type: 'Literature', item_subtype: 'article',
                   media_type: 'article', file_access_level: 'open',
                   place_of_publication: 'London, United Kingdom' },
        compounds: { titles: [{ 'value' => 'Notes on Erasure as Compositional Method', 'lang' => 'en' }],
                     dates: [{ 'value' => '2025-01-15', 'date_type' => 'Issued' }],
                     contributors: [{ 'contributor_name' => 'Avery Brooks', 'role_label' => 'author' }],
                     licenses: [{ 'rights_label' => 'CC BY 4.0' }] } },
      { file: 'bonfire-collection.png',
        scalars: { title: ['Workbook & Sketchbooks 2024-2025'],
                   description: 'A curated set of sketches, notes, and process documentation spanning the Bonfire portfolio.',
                   context_statement: 'Selected and ordered by the artist; original notebooks held in the personal archive.',
                   date_created: '2024-01-01', date_made_public: '2025-02-20',
                   portfolio_item_type: 'Collection', item_subtype: 'curated_set',
                   media_type: 'mixed', file_access_level: 'open',
                   extent: '47 items', extent_type: 'items', collection_order: 'chronological' },
        compounds: { titles: [{ 'value' => 'Workbook & Sketchbooks 2024-2025', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Avery Brooks', 'role_label' => 'creator' }] } }
    ]
  },
  {
    portfolio: {
      scalars: {
        title: ['Portfolio: Ten Walks Across the Fens'],
        description: 'A walking-and-drawing practice across East Anglian wetlands, presented across drawing, public exhibition, written reflection, and a curated sketchbook archive.',
        context_statement: 'Submitted as a REF 2029 unit-of-assessment portfolio in Art and Design, foregrounding walking as embodied research methodology.',
        date_created: '2023-09-01',
        date_made_public: '2025-04-10',
        date_range_of_outputs: '2023-09 / 2025-03',
        publisher: ['University of the Arts London'],
        portfolio_identifier: 'raid:placeholder-fens-2025',
        keyword: %w[walking drawing landscape East-Anglia practice-research],
        research_group: ['Centre for Research in Landscape Practice'],
        rights_statement: 'Metadata is licensed under Creative Commons Zero (CC0 1.0).',
        file_access_level: 'open',
        ref_unit_of_assessment: '32 - Art and Design: History, Practice and Theory'
      },
      compounds: {
        titles: [{ 'value' => 'Portfolio: Ten Walks Across the Fens', 'lang' => 'en' }],
        dates: [{ 'value' => '2023-09-01/2025-03-30', 'date_type' => 'DateRange', 'date_information' => 'project span' }],
        contributors: [
          { 'given_name' => 'Niamh', 'family_name' => "O'Brien", 'contributor_name' => "Niamh O'Brien",
            'name_type' => 'Personal', 'role_label' => 'artist',
            'name_identifier' => '0000-0001-3456-7890', 'scheme_uri' => 'https://orcid.org',
            'affiliation' => 'University of the Arts London', 'affiliation_identifier' => 'https://ror.org/04xpkdr30' }
        ],
        identifiers: [{ 'value' => 'doi:10.1234/fens.2025', 'identifier_type' => 'doi' }],
        funding_references: [
          { 'funder_name' => 'Leverhulme Trust', 'funder_identifier' => 'https://ror.org/012mzw131',
            'funder_identifier_type' => 'ROR', 'award_number' => 'RPG-2023-117',
            'award_title' => 'Walking the Wetlands: Landscape Research in Practice' }
        ],
        organisational_units: [
          { 'name' => 'Centre for Research in Landscape Practice', 'pid' => 'https://ror.org/04xpkdr30', 'unit_type' => 'Research Centre' }
        ],
        licenses: [
          { 'rights_label' => 'CC BY-NC 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc/4.0/',
            'rights_identifier' => 'CC-BY-NC-4.0', 'rights_identifier_scheme' => 'SPDX', 'holder' => "Niamh O'Brien" }
        ]
      }
    },
    children: [
      { file: 'fens-artefact.png',
        scalars: { title: ['Walk #3: Wicken Fen (charcoal on Khadi paper)'],
                   description: 'Large-format charcoal drawing made in situ over a single low-tide morning at Wicken Fen.',
                   context_statement: 'Part of a series of ten in-situ drawings; original now in the Norwich Castle collection.',
                   date_created: '2024-04-18', date_made_public: '2024-09-14',
                   portfolio_item_type: 'Artefact', item_subtype: 'drawing',
                   media_type: 'image', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Walk #3: Wicken Fen', 'lang' => 'en' }],
                     dates: [{ 'value' => '2024-04-18', 'date_type' => 'Created' }],
                     contributors: [{ 'contributor_name' => "Niamh O'Brien", 'role_label' => 'artist' }],
                     licenses: [{ 'rights_label' => 'CC BY-NC 4.0' }] } },
      { file: 'fens-event.png',
        scalars: { title: ['Solo Exhibition: Saltmarsh Light'],
                   description: 'A six-week solo exhibition at the Sainsbury Centre presenting all ten Walks drawings with accompanying field recordings.',
                   context_statement: 'Curated by the artist with sound design by Em Patel.',
                   date_created: '2024-09-14', date_made_public: '2024-09-14',
                   portfolio_item_type: 'Event', item_subtype: 'exhibition',
                   media_type: 'event', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Saltmarsh Light', 'lang' => 'en' }],
                     dates: [{ 'value' => '2024-09-14/2024-10-26', 'date_type' => 'EventDateRange', 'date_information' => 'six-week run' }],
                     contributors: [{ 'contributor_name' => "Niamh O'Brien", 'role_label' => 'curator' },
                                    { 'contributor_name' => 'Em Patel', 'role_label' => 'sound designer' }],
                     geo_locations: [{ 'place_name' => 'Sainsbury Centre, Norwich',
                                       'point_latitude' => '52.6209', 'point_longitude' => '1.2391' }] } },
      { file: 'fens-literature.png',
        scalars: { title: ['On Walking and Drawing: Notes from the Fens'],
                   description: 'A book chapter on walking as a research methodology for landscape drawing.',
                   context_statement: "Published in Hayes, K. (ed.) Practice in the Field, Routledge, 2025.",
                   date_created: '2024-12-02', date_made_public: '2025-03-15',
                   portfolio_item_type: 'Literature', item_subtype: 'chapter',
                   media_type: 'article', file_access_level: 'open',
                   place_of_publication: 'Abingdon, United Kingdom' },
        compounds: { titles: [{ 'value' => 'On Walking and Drawing: Notes from the Fens', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => "Niamh O'Brien", 'role_label' => 'author' }],
                     identifiers: [{ 'value' => '978-1-032-12345-6', 'identifier_type' => 'isbn' }],
                     licenses: [{ 'rights_label' => 'CC BY 4.0' }] } },
      { file: 'fens-collection.png',
        scalars: { title: ['Field Notebooks 2023-2024'],
                   description: 'A curated set of twelve field notebooks made during the Walks, including pencil sketches, pressed plant matter, and ink notations.',
                   context_statement: 'Selected by the artist; originals held at the UAL Archives & Special Collections.',
                   date_created: '2023-09-01', date_made_public: '2025-02-12',
                   portfolio_item_type: 'Collection', item_subtype: 'curated_set',
                   media_type: 'mixed', file_access_level: 'open',
                   extent: '12 notebooks', extent_type: 'items', collection_order: 'chronological' },
        compounds: { titles: [{ 'value' => 'Field Notebooks 2023-2024', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => "Niamh O'Brien", 'role_label' => 'creator' }] } }
    ]
  },
  {
    portfolio: {
      scalars: {
        title: ['Portfolio: The Glassmaker\'s Daughter'],
        description: "Development and production of a new full-length play, presented across script, premiere production, devising essay, and rehearsal archive.",
        context_statement: 'Submitted as a REF 2029 portfolio in Drama, demonstrating playwriting and devised theatre as research practice.',
        date_created: '2022-11-01',
        date_made_public: '2025-04-22',
        date_range_of_outputs: '2022-11 / 2025-04',
        publisher: ['Queen Mary University of London'],
        portfolio_identifier: 'raid:placeholder-glassmaker-2025',
        keyword: %w[playwriting devised-theatre new-writing practice-research],
        research_group: ['Centre for Performance Practice and Research'],
        rights_statement: 'Metadata is licensed under Creative Commons Zero (CC0 1.0).',
        file_access_level: 'open',
        ref_unit_of_assessment: '33 - Music, Drama, Dance, Performing Arts, Film and Screen Studies'
      },
      compounds: {
        titles: [{ 'value' => "Portfolio: The Glassmaker's Daughter", 'lang' => 'en' }],
        dates: [{ 'value' => '2022-11-01/2025-04-22', 'date_type' => 'DateRange', 'date_information' => 'development to premiere' }],
        contributors: [
          { 'given_name' => 'Tomasz', 'family_name' => 'Kowalski', 'contributor_name' => 'Tomasz Kowalski',
            'name_type' => 'Personal', 'role_label' => 'playwright',
            'name_identifier' => '0000-0001-4567-8901', 'scheme_uri' => 'https://orcid.org',
            'affiliation' => 'Queen Mary University of London', 'affiliation_identifier' => 'https://ror.org/026zzn846' },
          { 'given_name' => 'Ada', 'family_name' => 'Mensah', 'contributor_name' => 'Ada Mensah',
            'name_type' => 'Personal', 'role_label' => 'director',
            'name_identifier' => '0000-0002-5678-9012' }
        ],
        identifiers: [{ 'value' => 'doi:10.1234/glassmaker.2025', 'identifier_type' => 'doi' }],
        funding_references: [
          { 'funder_name' => 'Arts Council England', 'funder_identifier' => 'https://ror.org/03b00gd55',
            'funder_identifier_type' => 'ROR', 'award_number' => 'ACE-NLP-2024-3344',
            'award_title' => 'National Lottery Project Grant: The Glassmaker\'s Daughter' }
        ],
        organisational_units: [
          { 'name' => 'Centre for Performance Practice and Research', 'pid' => 'https://ror.org/026zzn846', 'unit_type' => 'Research Centre' }
        ],
        licenses: [
          { 'rights_label' => 'All rights reserved (script)', 'holder' => 'Tomasz Kowalski' },
          { 'rights_label' => 'CC BY-NC 4.0 (metadata)', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc/4.0/' }
        ]
      }
    },
    children: [
      { file: 'glassmaker-artefact.png',
        scalars: { title: ["The Glassmaker's Daughter - Rehearsal Draft"],
                   description: 'Full-length play, two acts, in rehearsal draft as used at the Royal Court Theatre.',
                   context_statement: 'Final draft to be published by Methuen Drama in Autumn 2025.',
                   date_created: '2024-09-30', date_made_public: '2025-04-22',
                   portfolio_item_type: 'Artefact', item_subtype: 'script',
                   media_type: 'text', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => "The Glassmaker's Daughter - Rehearsal Draft", 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Tomasz Kowalski', 'role_label' => 'playwright' }],
                     licenses: [{ 'rights_label' => 'All rights reserved', 'holder' => 'Tomasz Kowalski' }] } },
      { file: 'glassmaker-event.png',
        scalars: { title: ['World Premiere - Royal Court Theatre'],
                   description: 'A four-week run of the world premiere at the Royal Court Jerwood Downstairs.',
                   context_statement: 'Directed by Ada Mensah with a cast of six. Press night attended by national reviewers.',
                   date_created: '2025-04-22', date_made_public: '2025-04-22',
                   portfolio_item_type: 'Event', item_subtype: 'performance',
                   media_type: 'event', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'World Premiere - Royal Court Theatre', 'lang' => 'en' }],
                     dates: [{ 'value' => '2025-04-22/2025-05-17', 'date_type' => 'EventDateRange', 'date_information' => 'four-week run' }],
                     contributors: [{ 'contributor_name' => 'Tomasz Kowalski', 'role_label' => 'playwright' },
                                    { 'contributor_name' => 'Ada Mensah', 'role_label' => 'director' }],
                     geo_locations: [{ 'place_name' => 'Royal Court Theatre, London',
                                       'point_latitude' => '51.4922', 'point_longitude' => '-0.1573' }] } },
      { file: 'glassmaker-literature.png',
        scalars: { title: ['Devising in Public: Reflections on a Three-Year Development'],
                   description: "A peer-reviewed essay on the three-year R&D process for The Glassmaker's Daughter.",
                   context_statement: 'Published in Contemporary Theatre Review, volume 35, issue 1.',
                   date_created: '2025-01-08', date_made_public: '2025-03-04',
                   portfolio_item_type: 'Literature', item_subtype: 'article',
                   media_type: 'article', file_access_level: 'open',
                   place_of_publication: 'London, United Kingdom' },
        compounds: { titles: [{ 'value' => 'Devising in Public: Reflections on a Three-Year Development', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Tomasz Kowalski', 'role_label' => 'author' }],
                     identifiers: [{ 'value' => 'doi:10.5678/ctr.2025.35.1.078', 'identifier_type' => 'doi' }],
                     licenses: [{ 'rights_label' => 'CC BY-NC 4.0' }] } },
      { file: 'glassmaker-collection.png',
        scalars: { title: ['Rehearsal Documentation Archive'],
                   description: 'Curated video, audio, and photographic documentation of the rehearsal process across three R&D residencies and the Royal Court run.',
                   context_statement: 'Selected and edited by the production team; materials cleared with all collaborators.',
                   date_created: '2023-02-01', date_made_public: '2025-05-17',
                   portfolio_item_type: 'Collection', item_subtype: 'archive',
                   media_type: 'mixed', file_access_level: 'open',
                   extent: '180 files', extent_type: 'items', collection_order: 'chronological' },
        compounds: { titles: [{ 'value' => 'Rehearsal Documentation Archive', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Tomasz Kowalski', 'role_label' => 'creator' },
                                    { 'contributor_name' => 'Ada Mensah', 'role_label' => 'creator' }] } }
    ]
  },
  {
    portfolio: {
      scalars: {
        title: ['Portfolio: Bodies in Common Ground'],
        description: 'A three-year participatory dance practice with non-professional performers, ' \
                     'presented across choreographic score, public performance, peer-reviewed essay, ' \
                     'and workshop documentation.',
        context_statement: 'Submitted as a REF 2029 portfolio in Dance, foregrounding community practice as research.',
        date_created: '2022-03-15',
        date_made_public: '2025-05-01',
        date_range_of_outputs: '2022-03 / 2025-04',
        publisher: ['University of Leeds'],
        portfolio_identifier: 'raid:placeholder-common-2025',
        keyword: %w[dance community-practice participatory-arts practice-research embodiment],
        research_group: ['Centre for Practice Research in the Arts'],
        rights_statement: 'Metadata is licensed under Creative Commons Zero (CC0 1.0).',
        file_access_level: 'open',
        ref_unit_of_assessment: '33 - Music, Drama, Dance, Performing Arts, Film and Screen Studies'
      },
      compounds: {
        titles: [{ 'value' => 'Portfolio: Bodies in Common Ground', 'lang' => 'en' }],
        dates: [{ 'value' => '2022-03-15/2025-04-12', 'date_type' => 'DateRange', 'date_information' => 'project span' }],
        contributors: [
          { 'given_name' => 'Marisol', 'family_name' => 'Rivera', 'contributor_name' => 'Marisol Rivera',
            'name_type' => 'Personal', 'role_label' => 'choreographer',
            'name_identifier' => '0000-0001-5678-9012', 'scheme_uri' => 'https://orcid.org',
            'affiliation' => 'University of Leeds', 'affiliation_identifier' => 'https://ror.org/024mrxd33' },
          { 'given_name' => 'Bilal', 'family_name' => 'Aslam', 'contributor_name' => 'Bilal Aslam',
            'name_type' => 'Personal', 'role_label' => 'community lead',
            'name_identifier' => '0000-0002-6789-0123' }
        ],
        identifiers: [{ 'value' => 'doi:10.1234/common.2025', 'identifier_type' => 'doi' }],
        funding_references: [
          { 'funder_name' => 'Economic and Social Research Council', 'funder_identifier' => 'https://ror.org/03n0ht308',
            'funder_identifier_type' => 'ROR', 'award_number' => 'ES/X045678/1',
            'award_title' => 'Bodies in Common Ground: Community Dance as Research' }
        ],
        organisational_units: [
          { 'name' => 'Centre for Practice Research in the Arts', 'pid' => 'https://ror.org/024mrxd33', 'unit_type' => 'Research Centre' },
          { 'name' => 'School of Performance and Cultural Industries', 'pid' => 'https://ror.org/024mrxd33', 'unit_type' => 'School' }
        ],
        licenses: [
          { 'rights_label' => 'CC BY-NC-SA 4.0', 'rights_uri' => 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
            'rights_identifier' => 'CC-BY-NC-SA-4.0', 'rights_identifier_scheme' => 'SPDX', 'holder' => 'Marisol Rivera' }
        ]
      }
    },
    children: [
      { file: 'common-artefact.png',
        scalars: { title: ['Score: 12 Bodies in a Square'],
                   description: 'Open-form choreographic score for twelve non-professional performers in a public square. Annotated with timing options and accessibility notes.',
                   context_statement: 'Score has been adapted and performed in four UK cities to date.',
                   date_created: '2023-05-10', date_made_public: '2024-11-04',
                   portfolio_item_type: 'Artefact', item_subtype: 'score',
                   media_type: 'text', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Score: 12 Bodies in a Square', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Marisol Rivera', 'role_label' => 'choreographer' }],
                     licenses: [{ 'rights_label' => 'CC BY-NC-SA 4.0' }] } },
      { file: 'common-event.png',
        scalars: { title: ['Community Performance - Manchester Piccadilly Gardens'],
                   description: 'A public performance of 12 Bodies in a Square with thirty local participants in Piccadilly Gardens.',
                   context_statement: 'Co-produced with Manchester Community Dance Network. Free and open to the public.',
                   date_created: '2024-07-13', date_made_public: '2024-07-13',
                   portfolio_item_type: 'Event', item_subtype: 'performance',
                   media_type: 'event', file_access_level: 'open' },
        compounds: { titles: [{ 'value' => 'Community Performance - Manchester Piccadilly Gardens', 'lang' => 'en' }],
                     dates: [{ 'value' => '2024-07-13', 'date_type' => 'Performed' }],
                     contributors: [{ 'contributor_name' => 'Marisol Rivera', 'role_label' => 'choreographer' },
                                    { 'contributor_name' => 'Bilal Aslam', 'role_label' => 'community lead' }],
                     geo_locations: [{ 'place_name' => 'Piccadilly Gardens, Manchester',
                                       'point_latitude' => '53.4810', 'point_longitude' => '-2.2374' }] } },
      { file: 'common-literature.png',
        scalars: { title: ['Towards a Common Ground: Reflections on Community Dance as Research'],
                   description: 'A peer-reviewed essay positioning community dance within practice-research methodologies.',
                   context_statement: 'Published in Research in Dance Education, volume 26, issue 2.',
                   date_created: '2024-12-15', date_made_public: '2025-02-28',
                   portfolio_item_type: 'Literature', item_subtype: 'article',
                   media_type: 'article', file_access_level: 'open',
                   place_of_publication: 'Abingdon, United Kingdom' },
        compounds: { titles: [{ 'value' => 'Towards a Common Ground', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Marisol Rivera', 'role_label' => 'author' }],
                     identifiers: [{ 'value' => 'doi:10.5678/rde.2025.26.2.115', 'identifier_type' => 'doi' }],
                     licenses: [{ 'rights_label' => 'CC BY 4.0' }] } },
      { file: 'common-collection.png',
        scalars: { title: ['Workshop Sequences 2022-2025'],
                   description: 'A curated set of workshop plans, participant reflections, and short video documentation across three years of community workshops.',
                   context_statement: 'Selected and ordered with participants; consent and release on file for all materials.',
                   date_created: '2022-03-15', date_made_public: '2025-04-30',
                   portfolio_item_type: 'Collection', item_subtype: 'curated_set',
                   media_type: 'mixed', file_access_level: 'open',
                   extent: '64 items', extent_type: 'items', collection_order: 'thematic' },
        compounds: { titles: [{ 'value' => 'Workshop Sequences 2022-2025', 'lang' => 'en' }],
                     contributors: [{ 'contributor_name' => 'Marisol Rivera', 'role_label' => 'creator' },
                                    { 'contributor_name' => 'Bilal Aslam', 'role_label' => 'creator' }] } }
    ]
  }
].freeze
# rubocop:enable Metrics/CollectionLiteralLength

puts "Admin set: #{ADMIN_SET_ID}"
puts "Seeding into tenant: #{begin
                               AccountElevator.current_tenant
                             rescue
                               ENV['ENACT_DEMO_TENANT']
                             end}"

def seed_children(spec)
  child_ids = []
  spec[:children].each do |c|
    puts "\n-- #{c[:scalars][:title].first} --"
    child = create_work(PortfolioItem, scalars: c[:scalars], compounds: c[:compounds])
    puts "   Item #{child.id} (#{c[:scalars][:portfolio_item_type]} / #{c[:scalars][:item_subtype]})"
    file_path = File.join(SEED_DIR, c[:file])
    if File.exist?(file_path)
      attach_file!(child, file_path)
    else
      puts "   ! missing image: #{file_path}"
    end
    child_ids << child.id.to_s
  end
  child_ids
end

def attach_children_to_portfolio(portfolio, child_ids)
  portfolio = Hyrax.query_service.find_by(id: portfolio.id)
  portfolio.member_ids = child_ids.map { |id| Valkyrie::ID.new(id) }

  first_child = Hyrax.query_service.find_by(id: child_ids.first)
  fs_id = first_child.representative_id || first_child.thumbnail_id || first_child.member_ids.first
  if fs_id
    portfolio.representative_id = fs_id
    portfolio.thumbnail_id      = fs_id
  end

  portfolio = Hyrax.persister.save(resource: portfolio)
  Hyrax.index_adapter.save(resource: portfolio)
  child_ids.each { |id| Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id:)) }
end

PORTFOLIOS.each do |spec|
  puts "\n=========================================="
  puts "  #{spec[:portfolio][:scalars][:title].first}"
  puts "=========================================="
  portfolio = create_work(Portfolio, scalars: spec[:portfolio][:scalars], compounds: spec[:portfolio][:compounds])
  puts "  -> Portfolio #{portfolio.id}"

  child_ids = seed_children(spec)
  attach_children_to_portfolio(portfolio, child_ids)
end

Hyrax::SolrService.commit
puts "\n\nAll #{PORTFOLIOS.size} portfolios seeded."
PORTFOLIOS.each do |spec|
  puts " - #{spec[:portfolio][:scalars][:title].first}"
end
