## MemoryFragment — one recovered memory of Fayde's past (ADR-0027).
##
## A fragment is pure data: an id, a short title and the text shown in the
## MemoryFragmentModal and the Memories archive. The ordered list lives in
## StoryConfig (assets/data/story/story_config.tres); the order is the story order.
##
## Design: design/gdd/memory-fragments.md
class_name MemoryFragment
extends Resource

## Stable id used by tests and the anchor lookup. Progress saves only a count.
@export var id: StringName = &""

## Short title shown above the text and in the archive list.
@export var title: String = ""

## Who is remembering or speaking, shown in small caps above the title. Optional.
@export var voice: String = ""

## The fragment text. Paragraphs are separated by a blank line.
@export_multiline var body: String = ""
