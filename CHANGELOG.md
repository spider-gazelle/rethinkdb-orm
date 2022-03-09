## Unreleased

### Fix

- reference kingsleyh/crystal-rethinkdb

## v6.0.0 (2022-03-08)

### Refactor

- update active-model using `JSON::Serializable` (#21)

## v5.0.4 (2022-02-22)

### Fix

- unique error field (#33)

## v5.0.3 (2022-02-17)

### Fix

- **associations**: cast child id to String in `has_one`
- **changefeed**: subtle exception bug
- update rethinkdb driver with better connection logic

## v5.0.1 (2021-08-21)

### Feat

- improve id generator

### Fix

- **changefeed**: `Iterator(Change(T))`

### Refactor

- **change**: remove `NamedTuple`

## v4.2.0 (2021-07-14)

### Refactor

- **collection**: implement `Enumerable`
- **association_collection**: implement `Enumerable`
- **queries**: deprecate `find_by` and `get_all`

### Perf

- **collection**: reduce iteratoration

### Fix

- **persistence**: use replace to ensure fields can be set to nil

## v3.2.2 (2021-02-16)

### Fix

- **persistence**: fix typo in `update`

## v3.2.1 (2021-02-03)

### Fix

- **error**: add fields to error message

## v3.2.0 (2021-01-15)

### Refactor

- **persistence**: slight improvment to persistence errors

## v3.1.2 (2020-12-03)

### Fix

- **connection**: check connection closed before yielding

## v3.1.1 (2020-10-15)

### Fix

- **settings**: correct typing for retry
- **connection**: retry queries

## v3.0.2 (2020-08-18)

### Fix

- **changefeed**: correct stop method return

## v3.0.1 (2020-08-18)

### Fix

- **changefeed**: throw on channel closed
- **validation:unique**: construct non-nil interfaces to transform procs, as nils are ignored

### Refactor

- use active-model 2.0.0

## v2.10.1 (2020-06-30)

### Fix

- **persistence**: correctly set _new_flag on successful persistence

## v2.9.1 (2020-06-15)

### Fix

- **LICENSE**: update copyright holder reference

## v2.9.0 (2020-05-18)

### Refactor

- **persistence**: run `valid?` after `before_*` callbacks run
- **persistence**: run `valid?` after `before_*` callbacks run

## v2.8.2 (2020-05-13)

### Fix

- **connection**: ignore 'Index already exists' errors

## v2.7.4 (2020-04-09)

### Fix

- crystal 34 compatibility
- crystal 34 compatibility

## v2.7.3 (2020-03-31)

### Fix

- **queries**: cast `exists?` QueryResult to bool

## v2.6.5 (2020-03-28)

### Feat

- **queries**: add `association_collection` which is a table scoped query in a `Collection`

### Perf

- **queries**: optimise `where`

## v2.6.4 (2020-03-26)

### Fix

- **collection**: iterate Atom results

## v2.6.2 (2020-03-18)

### Fix

- **connection**: avoid duplicate tables on start-up with multiple writers

## v2.6.1 (2020-03-11)

### Refactor

- **connection**: remove `r` shortcut in favour of `alias R = RethinkDB`

## v2.6.0 (2020-03-11)

### Feat

- **lock**: implement `RethinkORM::Lock` and `RethinkORM::Lock::Reentrant`

### Fix

- **base**: prevent mass assignment on document id

## v2.5.0 (2020-03-05)

### Refactor

- **queries**: remove redundant iterators
- **collection**: refactor collection logic, support cursor cancellation

## v2.4.4 (2020-03-05)

### Fix

- **table**: remove explicit `@@table_name` instantiation before setting via macro

## v2.4.2 (2020-02-03)

### Feat

- **persistence**: treat empty id values as a new object
- **persistence**: treat empty id values as a new object
- **changefeed**: `Changefeed::Event::Deleted` events include destroyed models
- **error**: `Error::DocumentInvalid#inspect_errors`

### Fix

- **queries**: fix `where` query attribute merge
- **associations**: model#parent returns nil for parent of unpersisted model
