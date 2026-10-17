class_name WebStorage
extends RefCounted
## The web build asks the browser, once, to keep the save (navigator.storage.persist).
## A browser may clear a site's storage when space is short; a granted request stops that.
## When the browser refuses, the menu says so once. Web only: on every other platform
## nothing is asked and nothing is shown. Presentation only - never read by the sim.

const REFUSED_LINE := "Your browser may clear this save when space is short."
## Settings keys (GameState.get_setting / set_setting).
const ASKED_KEY := "storage_asked"
const SHOWN_KEY := "storage_notice_shown"
## The browser's answers: "granted", "refused", "unsupported", or "pending" while it decides.
const PENDING := "pending"


static func on_web() -> bool:
	return OS.has_feature("web")


## Ask only on the web, and only until the browser has given a final answer.
static func should_ask(web: bool, asked: bool) -> bool:
	return web and not asked


## A final answer ends the asking; "pending" (a prompt still open) and "" keep it open.
static func is_final(answer: String) -> bool:
	return answer in ["granted", "refused", "unsupported"]


## The one line is due when the browser refused and it has not been shown before.
static func notice_due(answer: String, shown_before: bool) -> bool:
	return answer == "refused" and not shown_before


## Ask the browser. Returns at once; read the answer later with answer().
static func ask() -> void:
	if not on_web():
		return
	JavaScriptBridge.eval(
			"window.__aflPersist='pending';(function(){try{var s=navigator.storage;"
			+ "if(!s||!s.persist||!s.persisted){window.__aflPersist='unsupported';return;}"
			+ "s.persisted().then(function(p){if(p){window.__aflPersist='granted';return;}"
			+ "return s.persist().then(function(g){window.__aflPersist=g?'granted':'refused';});})"
			+ ".catch(function(){window.__aflPersist='unsupported';});"
			+ "}catch(e){window.__aflPersist='unsupported';}})();", true)


static func answer() -> String:
	if not on_web():
		return ""
	return str(JavaScriptBridge.eval("window.__aflPersist||''", true))
