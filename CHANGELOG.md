## [1.4.2] - 2022-02-28

* Fix null dereference when applying search query

## [1.4.1] - 2022-02-13

* Improve documentation

## [1.4.0] - 2021-05-13

* Handle `id:` and `#custom-id` links
* Add methods for resolving section links to `OrgControllerData`
  * `sectionWithId`
  * `sectionWithCustomId`
  * `sectionForTarget`

## [1.3.0] - 2021-04-19

* Relicense under the MIT License

## [1.2.0] - 2021-03-19

* Support loading images via `loadImage` callback supplied to `Org` or
  `OrgEvents`

## [1.1.1] - 2021-03-14

* Fix nullability issues with headline, src block
* `OrgTheme.of`, `OrgEvents.of` now return non-nullable instances; they will
  throw if the expected widgets are not present in the supplied context

## [1.1.0] - 2021-03-11

* Support automatic [state restoration](https://flutter.dev/go/state-restoration-design)
  * Manual state management facilities `initialState` and `stateListener` on
    `OrgController` have been removed
  * Instead provide `restorationId` to `Org` or `OrgController`

## [1.0.0] - 2021-03-11

* Migrate to non-nullable by default

## [0.10.0] - 2021-03-03

* Property lines, planning/clock lines no longer wrap

## [0.9.0] - 2021-02-16

* Fix handling of drawer content
* Handle planning/clock lines as separate elements

## [0.8.1] - 2020-12-02

* Take theme brightness from current `ThemeData`, not `MediaQuery`

## [0.8.0] - 2020-08-26

* Change effects of `hideMarkup` option:
  * Drawers and meta lines no longer hidden, but rather faded (reduced opacity)
  * Block headers, meta lines truncated to fit document width with no wrapping

## [0.7.0] - 2020-07-22

* Prettify org entities

## [0.6.2] - 2020-07-16

* Update flutter_tex_js to v0.1.1 (LaTeX fragments now follow ambient font size)

## [0.6.1] - 2020-07-16

* Fix extraneous line break following LaTeX block

## [0.6.0] - 2020-07-15

* Support LaTeX inline and block fragments

## [0.5.2] - 2020-06-28

* Add `shrinkWrap` option to `OrgDocumentWidget` and `OrgSectionWidget`

## [0.5.1] - 2020-06-22

* Fix error handling source blocks with no language specification

## [0.5.0] - 2020-06-22

* Highlight syntax in source blocks

## [0.4.2] - 2020-06-09

* Fix headline layout with long tags

## [0.4.1] - 2020-06-04

* Replace `OrgControllerData.initialScrollOffset` with
  `OrgControllerData.scrollController`

## [0.4.0] - 2020-06-03

* Changes to `OrgControllerData` members
  * E.g. `OrgController.of(context).hideMarkup` is now a setter/getter rather
    than a `ValueNotifier`
* Add ability to save/restore transient view state (currently section
  visibilities, scroll position)
  * See `initialState`, `stateListener` args to `OrgController` constructor

## [0.3.1] - 2020-05-23

* Add `hideMarkup` argument to `OrgController` constructor

## [0.3.0+1] - 2020-05-21

* Add example

## [0.3.0] - 2020-05-15

* Pad root view to safe area
* Inherit visibility state when narrowing
* Various refactoring

## [0.2.1] - 2020-05-09

* Fix color of inline footnote body

## [0.2.0] - 2020-05-08

* Fix table width
* Fix block, drawer trailing space when collapsed
* Only break link text by character when the text is (probably) a URL
* Use a ListView as document/section root
* Set document padding in theme: see `OrgThemeData.rootPadding`

## [0.1.1] - 2020-05-06

* Right-align table columns that are primarily numeric

## [0.1.0] - 2020-05-05

* Initial release
