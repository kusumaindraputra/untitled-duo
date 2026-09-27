## FeedbackLink — builds and opens the beta feedback form link (ADR-0045, beta plan 5.2).
##
## The main menu and the run summary show a Feedback button only when
## [method is_available] is true, so a build without a form URL shows nothing.
class_name FeedbackLink
extends RefCounted

const CONFIG: FeedbackConfig = preload("res://assets/data/feedback_config.tres")


## True when [param cfg] has an http(s) form URL.
static func is_available(cfg: FeedbackConfig = CONFIG) -> bool:
	if cfg == null:
		return false
	var url: String = cfg.form_url.strip_edges()
	return url.begins_with("https://") or url.begins_with("http://")


## The URL to open for [param version], with the version pre-filled when the config
## names a query key. "" when no form is configured.
static func url_for(version: String, cfg: FeedbackConfig = CONFIG) -> String:
	if not is_available(cfg):
		return ""
	var url: String = cfg.form_url.strip_edges()
	if cfg.version_param.is_empty():
		return url
	var sep: String = "&" if url.contains("?") else "?"
	return "%s%s%s=%s" % [url, sep, cfg.version_param.uri_encode(), version.uri_encode()]


## Opens the form in the system browser (a new tab on the web build).
static func open(version: String, cfg: FeedbackConfig = CONFIG) -> void:
	var url: String = url_for(version, cfg)
	if not url.is_empty():
		OS.shell_open(url)
