## hud_readout_feedback_link_test.gd — Beta feedback form link (ADR-0045, beta plan 5.2).
##
## Coverage:
##   HR-20: no URL or a non-http URL means no link
##   HR-21: the version is appended with the configured query key, URL-encoded
##   HR-22: copy for both buttons exists
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func _cfg(url: String, param: String = "") -> FeedbackConfig:
	var c := FeedbackConfig.new()
	c.form_url = url
	c.version_param = param
	return c


func test_link_needs_an_http_url() -> void:
	assert_bool(FeedbackLink.is_available(_cfg(""))).is_false()
	assert_bool(FeedbackLink.is_available(_cfg("forms.example/abc"))).is_false()
	assert_bool(FeedbackLink.is_available(null)).is_false()
	assert_bool(FeedbackLink.is_available(_cfg("https://forms.example/abc"))).is_true()
	assert_str(FeedbackLink.url_for("0.9.0", _cfg(""))).is_empty()


func test_version_is_appended_with_query_key() -> void:
	assert_str(FeedbackLink.url_for("0.9.0", _cfg("https://f.example/x"))).is_equal("https://f.example/x")
	assert_str(FeedbackLink.url_for("0.95.0 beta", _cfg("https://f.example/x", "entry.1"))) \
		.is_equal("https://f.example/x?entry.1=0.95.0%20beta")
	assert_str(FeedbackLink.url_for("1", _cfg("https://f.example/x?usp=pp", "v"))) \
		.is_equal("https://f.example/x?usp=pp&v=1")


func test_button_copy_exists() -> void:
	assert_str(COPY.menu_feedback).is_not_empty()
	assert_str(COPY.summary_feedback).is_not_empty()
