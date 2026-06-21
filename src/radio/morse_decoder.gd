class_name MorseDecoder
extends RefCounted
## The player's manual copy of an incoming message. As they listen through the
## static they build up Morse token by token (or letter by letter); this holds
## that working copy and can commit it to the notebook as a transcript. What
## they copy is their *record* — it may differ from what was actually sent, and
## the notebook may corrupt it later.

var tokens: PackedStringArray = []   ## e.g. ["-.-.", "---", "-.."]


func clear() -> void:
	tokens.clear()


func add_token(morse_token: String) -> void:
	tokens.append(morse_token)


func add_word_break() -> void:
	tokens.append("/")


func backspace() -> void:
	if not tokens.is_empty():
		tokens.remove_at(tokens.size() - 1)


func morse() -> String:
	return " ".join(tokens)


func text() -> String:
	return MorseSystem.decode(morse())


## How close the player's copy is to what was sent, 0..1.
func accuracy(actual_text: String) -> float:
	return MorseSystem.score_fidelity(actual_text, text())


## File the working copy into the notebook as a transcript and clear it.
func commit_to_notebook(title: String = "Copied traffic") -> Dictionary:
	var entry := Notebook.add_entry(
		Notebook.Kind.MORSE_TRANSCRIPT, title, text(),
		{"morse": morse()}, Notebook.Trust.UNCERTAIN)
	clear()
	return entry
