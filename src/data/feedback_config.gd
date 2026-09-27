## FeedbackConfig — where the in-game "Feedback" buttons send players (ADR-0045).
##
## Authored as assets/data/feedback_config.tres. The beta feedback form does not exist
## yet, so [member form_url] ships empty and the buttons stay hidden until it is set.
## Read through FeedbackLink.
class_name FeedbackConfig
extends Resource

## Full https URL of the feedback form. Empty = no Feedback button anywhere.
@export var form_url: String = ""
## Optional query key that pre-fills the game version on the form (for example a
## Google Forms "entry.123456" id). Empty = the URL is opened as is.
@export var version_param: String = ""
