# Enact Hyku Theme

Initial deployable prototype theme matching the [`Enact Prototype.html` design](https://api.anthropic.com/v1/design/h/-YwUpek5I1Br3V_DzVs0_A?open_file=Enact+Prototype.html) handoff bundle, dated 2026-05-11. Implemented in the knapsack on branch `enact-prototype-theme` (2026-05-19).

## Scope

This is **Slice T** from the [scope discussion](https://github.com/notch8/hyku-community-issues/issues/91): theme-first, no work types, no compound widgets, no licensing v2 surface. Deployable to demo the visual identity to CoSector and the pathfinder partners.

What this branch does:

- Registers `enact` home theme and `enact_show` show theme (selectable from the per-tenant Appearance admin).
- Sets the full design-token system (warm paper canvas, Instrument Serif display, hairline borders, terracotta accent) as a CSS layer scoped to `body.enact`.
- Overrides the masthead, logo, homepage content, and footer to match the prototype's editorial layout.
- Adds tenant-configurable color presets via `theme_custom_colors`. A tenant admin can hit Appearance > Apply Theme Colors to repaint Hyku's chrome to match.

What this branch deliberately does **not** do:

- No new Hyrax work types. Catalog still shows whatever the tenant has deposited (typically GenericWork).
- No compound contributor widget, deposit wizard, or license library editor. Those land later.
- No 7-tab portfolio show or type-aware item show. Those need PortfolioResource and PortfolioItemResource models, which are not in this branch.
- No bespoke catalog gallery view. The `.card` rules in `enact.scss` restyle Hyku's existing Blacklight cards in the Enact aesthetic without per-view overrides; a richer card design comes later.

## Activation per tenant

1. Sign in as a tenant admin.
2. Go to **Dashboard > Configuration > Appearance**.
3. **Themes** tab > Home Page Theme > select **"Enact (practice research)"**.
4. (Optional) Show Page Theme > **"Enact Show Page"**.
5. (Optional) **Colors** tab > **Apply Theme Colors** to set Hyku's chrome colors (buttons, navbar links, etc.) to the Enact palette. Individual colors remain editable afterwards.
6. Save.

## File map

| File | Purpose |
|---|---|
| [`config/home_themes.yml`](../config/home_themes.yml) | Knapsack-level override of Hyku's `home_themes.yml`. Adds the `enact` entry. Loaded via `Hyku::Application.path_for`, which checks the knapsack first. |
| [`config/show_themes.yml`](../config/show_themes.yml) | Same, adds `enact_show`. |
| [`app/assets/stylesheets/themes/enact.scss`](../app/assets/stylesheets/themes/enact.scss) | Full design system. Scoped to `body.enact`. Imports Instrument Serif / Geist / JetBrains Mono from Google Fonts. Loaded by both Hyku's `@import "themes/*"` glob and the explicit link in `_head_tag_extras.html.erb`. |
| [`app/assets/stylesheets/themes/enact_show.scss`](../app/assets/stylesheets/themes/enact_show.scss) | Show-page-only adjustments. Scoped to `body.enact_show`. |
| [`app/assets/config/hyku_knapsack_manifest.js`](../app/assets/config/hyku_knapsack_manifest.js) | Sprockets manifest. Links the two theme SCSS files and the themes image tree for production precompile. |
| [`app/views/_head_tag_extras.html.erb`](../app/views/_head_tag_extras.html.erb) | Knapsack root override. Adds an explicit `<link>` to `themes/enact.css` (and `enact_show.css`) when the tenant is on the matching theme, so the SCSS does not depend on Hyrax's `@import "themes/*"` glob finding engine-contributed files. Preserves Hyku's favicon and MS-tile meta tags verbatim in the else branch. |
| [`app/views/_logo.html.erb`](../app/views/_logo.html.erb) | Knapsack root override. Renders the italic-serif Enact wordmark when `home_page_theme == 'enact'`; otherwise renders Hyku's default. Applied on every page using `layouts/hyrax.html.erb`. |
| [`app/views/_masthead.html.erb`](../app/views/_masthead.html.erb) | Knapsack root override. Paper-toned navbar when on the Enact theme; Hyku's dark navbar otherwise. Applied on every page using `layouts/hyrax.html.erb`. |
| [`app/views/shared/_footer.html.erb`](../app/views/shared/_footer.html.erb) | Knapsack root override. Light Enact footer when on the Enact theme; Hyku default otherwise. Only renders on splash and homepage controllers (Hyku layout convention; see `hyrax.html.erb:34`). |
| [`app/views/themes/enact/hyrax/homepage/_home_content.html.erb`](../app/views/themes/enact/hyrax/homepage/_home_content.html.erb) | Editorial homepage body: hero with eyebrow + italic headline + lede + CTAs + search bar; recently deposited (cards); featured collections; pathfinder note. Loaded via `Hyku::HomePageThemesBehavior` which injects the `themes/enact/` view path only on `HomepageController`, so this file is naturally scoped to homepage rendering. |
| [`app/views/layouts/homepage.html.erb`](../app/views/layouts/homepage.html.erb) | Knapsack root override of Hyku's homepage layout. Suppresses the `image-masthead` block (banner image + site title + search controls) when on the Enact theme. Falls through to Hyku's default for every other theme. Required because Hyku's default homepage layout forces a banner-image header that conflicts with the editorial paper-canvas aesthetic. |
| `app/assets/images/themes/enact/enact.jpg` | Theme preview thumbnail shown in Appearance > Themes. Required by [`hyrax-webapp/app/views/hyrax/admin/appearances/_theme_form.html.erb`](../hyrax-webapp/app/views/hyrax/admin/appearances/_theme_form.html.erb) line 5; raises `Sprockets::Rails::Helper::AssetNotFound` if missing. |
| `app/assets/images/themes/enact_show/enact_show.jpg` | Same, for the show theme. |

### Why some files live at the knapsack root vs under `themes/enact/`

Hyku's theme system (`Hyku::HomePageThemesBehavior`) prepends `app/views/themes/<theme_name>/` to view paths, but only on three controllers: `HomepageController`, `PagesController`, `ContactFormController`. On work show pages, catalog browse, dashboards, etc., theme view paths are *not* injected and `themes/enact/_masthead.html.erb` would never be found.

To get consistent chrome across every page, masthead / logo / footer overrides live at the **knapsack root** (`app/views/_masthead.html.erb` etc.) with a conditional `if home_page_theme == 'enact'`. They render the Enact markup for tenants on this theme and fall through to Hyku's default verbatim otherwise. The knapsack engine's `after_initialize` block (see `lib/hyku_knapsack/engine.rb:102-106`) prepends `<knapsack>/app/views` to every controller's view_paths, so these overrides apply universally.

Files that are inherently homepage-scoped (like `_home_content.html.erb`) stay under `themes/enact/` because the homepage controller is one of the three that does inject theme views.

## Tenant-configurable colors

`config/home_themes.yml` declares 22 colors under `enact.theme_custom_colors`, mapping the Enact palette to Hyku's named chrome colors:

| Enact token | Hyku chrome target |
|---|---|
| Canvas `#F6F2EA` | `header_and_footer_background_color`, `facet_panel_background_color` |
| Paper `#FBF8F2` | `navbar_background_color`, `default_button_background_color` |
| Ink `#1A1714` | `header_and_footer_text_color`, `navbar_link_text_hover_color`, `default_button_text_color`, `facet_panel_text_color`, `collection_banner_text_color` |
| Muted `#6B635A` | `navbar_link_text_color`, `footer_link_color` |
| Hairline `#E5DFD3` | `default_button_border_color` |
| Accent `#C76A4A` | `link_color`, `primary_button_background_color`, `primary_button_border_color` |
| Accent dark `#B05A3A` | `link_hover_color`, `primary_button_hover_color` |

A tenant admin can override any of these per-tenant after applying the preset. The `body.enact` SCSS rules use the Enact tokens directly (`--enact-accent`, etc.) so the chrome can drift from the theme tokens if a tenant prefers.

## Known limitations (Phase 1)

1. ~~**SCSS glob inclusion.**~~ **Resolved 2026-05-20.** Two-part fix:
   - `_head_tag_extras.html.erb` emits an explicit `stylesheet_link_tag 'themes/enact'` when the home theme is active, so the SCSS load no longer depends on Hyku's `@import "themes/*"` glob finding engine-contributed files.
   - `config/initializers/enact_theme_assets.rb` adds the theme CSS and JPG files to `Rails.application.config.assets.precompile`. Required because the Docker dev-staging deploy runs Rails in production mode; without this, Sprockets raises `AssetNotPrecompiledError`. Run `RAILS_ENV=production bundle exec rake assets:precompile` after pulling this branch (or whatever your deploy invokes for asset compilation).

2. **Google Fonts at runtime.** The SCSS uses `@import url("https://fonts.googleapis.com/...")` to load Instrument Serif, Geist, and JetBrains Mono. Acceptable for the demo. For production, self-host the fonts or move to `@font-face` declarations bundled with the knapsack to remove the external dependency and the privacy implications.

3. **Catalog cards.** The `.card` rule in `enact.scss` restyles Hyku's existing Blacklight cards but does not change the card content (title, type, thumb). A bespoke `_index_list_default.html.erb` and `_document_gallery_default.html.erb` override would land the editorial card layout the prototype shows on Browse. Hold for Slice C.

4. **Show page structure.** `enact_show.scss` restyles metadata tables and the title block; chrome (masthead, navbar) inherits the `body.enact` colors via SCSS. But the 7-tab portfolio show page **layout** from the prototype is a structural change requiring `PortfolioResource` and `PortfolioItemResource` models. Out of Slice T scope; lands in Slice D once work types exist. In the meantime, the show page will look like a stock Hyku work page with the Enact paper-toned chrome around it.

5. **Submodule.** This branch does not modify `hyrax-webapp/`. All overrides live in the knapsack root.

6. **Theme preview JPGs are wireframe placeholders.** Generated locally via ImageMagick from SVG; my build did not have FreeType so text labels rendered with the system fallback font. The layout shapes are correct. Replace with proper screenshots once the theme is rendered live: `magick screenshot.png -resize 750x791 app/assets/images/themes/enact/enact.jpg` (and similarly for `enact_show.jpg`).

7. **Homepage vs catalog: they are different pages in Hyku.** The prototype's "Browse" view (image #6 in design feedback) - hero + search + facet sidebar + portfolio cards - corresponds to Hyku's `/catalog` (Blacklight `CatalogController`), not to `/` (`HomepageController`). The Enact homepage in this branch shows the hero, a search bar that submits to the catalog, recently deposited cards, and a pathfinder note. The full faceted browse layout from the prototype is **Slice C** work and will theme `/catalog` directly. If the desired demo flow is "users land on the catalog directly", route `/` to redirect to `/catalog` for the Enact tenant in a follow-up.

8. **Wordmark text comes from `application_name`.** The italic wordmark in the masthead and footer renders the tenant's `application_name` setting. If it says "Hyku" instead of "Enact", change it in Admin > Appearance > Site Name. The wordmark falls back to literal "Enact" only when `application_name` is blank.

## Branch / next steps

Branch: `enact-prototype-theme` (from `main` at 2026-05-19).

Recommended next slices in order:

- **Slice C** (~3-5 days): catalog card overrides + show-page block overrides + a header-nav extension. Adds visual fidelity without committing to data-model work.
- **Slice D** (~7-10 days, post-Jenny P0): generate `PortfolioResource` and `PortfolioItemResource` via the knapsack generator, then 7-tab portfolio show + type-aware item show structure.
- **Slice E** (~10-15 days, post-Jenny P0): compound widgets and the licensing v2 surface per [#91 Discovery 06](https://github.com/notch8/hyku-community-issues/issues/91#issuecomment-4453747422).
