# jd.awk — core JSONL scanning logic for jd (POSIX awk)
#
# Modes:
#   scan   -> single JSON summary/error object, exit 0/1
#   fields -> JSONL describing field types; exits 0 on success, 1 on parse errors
#   drift  -> JSONL describing schema drift; exits 0 on success, 1 on parse errors

BEGIN {
	if (mode == "") mode = "scan"
	if (ignore_empty == "") ignore_empty = 0

	total_lines = 0
	records = 0
	ignored_empty = 0
	exit_code = 0
	first_record_line = 0
	last_record_line = 0

	fields_n = 0
	drift_events_n = 0
	type_changes_n = 0
}

function json_escape(s,    out) {
	out = s
	gsub(/\\/,"\\\\",out)
	gsub(/"/,"\\\"",out)
	gsub(/\t/,"\\t",out)
	gsub(/\r/,"\\r",out)
	gsub(/\n/,"\\n",out)
	gsub(sprintf("%c",8),"\\b",out)   # backspace
	gsub(sprintf("%c",12),"\\f",out)  # formfeed
	return out
}

function out_error(line_no, col_no, code) {
	printf("{\"type\":\"error\",\"line\":%d,\"col\":%d,\"error\":\"%s\"}\n", line_no, col_no, json_escape(code))
}

function out_summary_scan(valid, lines) {
	printf("{\"type\":\"summary\",\"valid\":%s,\"lines\":%d}\n", valid ? "true" : "false", lines)
}

# ---- JSON parser (single-line JSON text) ----

function is_ws(c) {
	return (c == " " || c == "\t" || c == "\r")
}

function skip_ws(pos,    c) {
	while (pos <= text_len) {
		c = substr(text, pos, 1)
		if (!is_ws(c)) break
		pos++
	}
	return pos
}

function err_set(code, pos) {
	if (err_code != "") return
	err_code = code
	err_pos = pos
}

function parse_literal(pos, lit,    n) {
	n = length(lit)
	if (substr(text, pos, n) == lit) {
		last_type = (lit == "true" || lit == "false") ? "bool" : "null"
		return pos + n
	}
	err_set("invalid_json", pos)
	return pos
}

function parse_number(pos,    rest) {
	rest = substr(text, pos)
	if (match(rest, /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/)) {
		last_type = "number"
		return pos + RLENGTH
	}
	err_set("invalid_json", pos)
	return pos
}

function parse_string(pos,    c, esc, hex) {
	# pos points to first character AFTER opening quote
	last_string = ""
	while (pos <= text_len) {
		c = substr(text, pos, 1)
		if (c == "\"") {
			last_type = "string"
			return pos + 1
		}
		if (c == "\\") {
			pos++
			if (pos > text_len) {
				err_set("unterminated_string", pos)
				return pos
			}
			esc = substr(text, pos, 1)
			if (esc == "u") {
				if (pos + 4 > text_len) {
					err_set("unterminated_string", pos)
					return pos
				}
				hex = substr(text, pos + 1, 4)
				if (hex !~ /^[0-9A-Fa-f]{4}$/) {
					err_set("invalid_json", pos)
					return pos
				}
				# keep escape as-is for key/value text; decoding is out of scope
				last_string = last_string "\\u" hex
				pos += 5
				continue
			}
			if (esc ~ /^[\"\\\/bfnrt]$/) {
				last_string = last_string "\\" esc
				pos++
				continue
			}
			err_set("invalid_json", pos)
			return pos
		}
		if (c ~ /[[:cntrl:]]/) {
			err_set("invalid_json", pos)
			return pos
		}
		last_string = last_string c
		pos++
	}
	err_set("unterminated_string", pos)
	return pos
}

function parse_array(pos, depth,    c) {
	# pos points to first character AFTER '['
	pos = skip_ws(pos)
	if (pos <= text_len && substr(text, pos, 1) == "]") {
		last_type = "array"
		return pos + 1
	}

	while (1) {
		pos = parse_value(pos, depth)
		if (err_code != "") return pos
		pos = skip_ws(pos)
		if (pos > text_len) {
			err_set("invalid_json", pos)
			return pos
		}
		c = substr(text, pos, 1)
		if (c == ",") {
			pos++
			pos = skip_ws(pos)
			continue
		}
		if (c == "]") {
			last_type = "array"
			return pos + 1
		}
		err_set("unexpected_token", pos)
		return pos
	}
}

function record_field(name, vtype, line_no) {
	if (!(name in field_seen)) {
		field_seen[name] = 1
		field_order[++fields_n] = name
		field_first_type[name] = vtype
		field_first_line[name] = line_no
	}
	field_last_line[name] = line_no

	# type set (for conflicts)
	field_types[name SUBSEP vtype] = 1
	if (field_last_type[name] != "" && field_last_type[name] != vtype) {
		type_changes_n++
		type_change_field[type_changes_n] = name
		type_change_line[type_changes_n] = line_no
		type_change_from[type_changes_n] = field_last_type[name]
		type_change_to[type_changes_n] = vtype
	}
	field_last_type[name] = vtype
}

function parse_object(pos, depth, line_no,    c, key, vtype) {
	# pos points to first character AFTER '{'
	pos = skip_ws(pos)
	if (pos <= text_len && substr(text, pos, 1) == "}") {
		last_type = "object"
		return pos + 1
	}

	while (1) {
		pos = skip_ws(pos)
		if (pos > text_len) {
			err_set("invalid_json", pos)
			return pos
		}
		if (substr(text, pos, 1) != "\"") {
			err_set("unexpected_token", pos)
			return pos
		}
		pos = parse_string(pos + 1)
		if (err_code != "") return pos
		key = last_string

		pos = skip_ws(pos)
		if (pos > text_len) {
			err_set("invalid_json", pos)
			return pos
		}
		if (substr(text, pos, 1) != ":") {
			err_set("unexpected_token", pos)
			return pos
		}
		pos = parse_value(pos + 1, depth)
		if (err_code != "") return pos
		vtype = last_type

		if ((mode == "fields" || mode == "drift") && depth == 1) {
			record_field(key, vtype, line_no)
		}

		pos = skip_ws(pos)
		if (pos > text_len) {
			err_set("invalid_json", pos)
			return pos
		}
		c = substr(text, pos, 1)
		if (c == ",") {
			pos++
			continue
		}
		if (c == "}") {
			last_type = "object"
			return pos + 1
		}
		err_set("unexpected_token", pos)
		return pos
	}
}

function parse_value(pos, depth,    c) {
	pos = skip_ws(pos)
	if (pos > text_len) {
		err_set("invalid_json", pos)
		return pos
	}
	c = substr(text, pos, 1)

	if (c == "{") return parse_object(pos + 1, depth + 1, NR)
	if (c == "[") return parse_array(pos + 1, depth + 1)
	if (c == "\"") return parse_string(pos + 1)
	if (c == "t") return parse_literal(pos, "true")
	if (c == "f") return parse_literal(pos, "false")
	if (c == "n") return parse_literal(pos, "null")
	if (c == "-" || c ~ /[0-9]/) return parse_number(pos)

	err_set("unexpected_token", pos)
	return pos
}

function validate_json_line(s,    pos, c) {
	text = s
	text_len = length(text)
	err_code = ""
	err_pos = 1
	last_type = ""
	last_string = ""

	pos = skip_ws(1)
	if (pos > text_len) {
		err_set("empty_line", 1)
		return err_code
	}

	c = substr(text, pos, 1)
	if (c !~ /^[\{\[\"]$/ && c !~ /^[-0-9]$/ && c !~ /^[tfn]$/) {
		err_set("non_json_line", pos)
		return err_code
	}

	pos = parse_value(pos, 0)
	if (err_code != "") return err_code

	pos = skip_ws(pos)
	if (pos <= text_len) {
		err_set("trailing_garbage", pos)
	}
	return err_code
}

function is_blank_line(s,    t) {
	t = s
	gsub(/[ \t\r]/, "", t)
	return (t == "")
}

{
	total_lines = NR
	if (is_blank_line($0)) {
		if (ignore_empty) {
			ignored_empty++
			next
		}
		validate_json_line($0)
		out_error(NR, err_pos, err_code)
		exit_code = 1
		exit 1
	}

	validate_json_line($0)
	if (err_code != "") {
		out_error(NR, err_pos, err_code)
		exit_code = 1
		exit 1
	}
	if ((mode == "fields" || mode == "drift") && last_type != "object") {
		out_error(NR, 1, "not_object")
		exit_code = 1
		exit 1
	}
	if (records == 0) first_record_line = NR
	records++
	last_record_line = NR
}

END {
	if (exit_code != 0) exit exit_code

	if (mode == "scan") {
		out_summary_scan(1, total_lines)
		exit 0
	}

	if (mode == "fields") {
		conflicts = 0
		for (i = 1; i <= fields_n; i++) {
			f = field_order[i]
			# gather all seen types (stable order: string, number, bool, null, object, array)
			types = ""
			conflict = 0

			if (field_types[f SUBSEP "string"]) types = types (types ? "," : "") "\"string\""
			if (field_types[f SUBSEP "number"]) types = types (types ? "," : "") "\"number\""
			if (field_types[f SUBSEP "bool"])   types = types (types ? "," : "") "\"bool\""
			if (field_types[f SUBSEP "null"])   types = types (types ? "," : "") "\"null\""
			if (field_types[f SUBSEP "object"]) types = types (types ? "," : "") "\"object\""
			if (field_types[f SUBSEP "array"])  types = types (types ? "," : "") "\"array\""

			# conflict if more than one type seen
			n_types = 0
			if (field_types[f SUBSEP "string"]) n_types++
			if (field_types[f SUBSEP "number"]) n_types++
			if (field_types[f SUBSEP "bool"]) n_types++
			if (field_types[f SUBSEP "null"]) n_types++
			if (field_types[f SUBSEP "object"]) n_types++
			if (field_types[f SUBSEP "array"]) n_types++
			if (n_types > 1) conflict = 1
			if (conflict) conflicts++

			printf("{\"type\":\"field\",\"field\":\"%s\",\"first_type\":\"%s\",\"types\":[%s],\"conflict\":%s}\n",
				json_escape(f),
				json_escape(field_first_type[f]),
				types,
				conflict ? "true" : "false")
		}
		printf("{\"type\":\"summary\",\"lines\":%d,\"records\":%d,\"fields\":%d,\"conflicts\":%d}\n", total_lines, records, fields_n, conflicts)
		exit 0
	}

	if (mode == "drift") {
		# Emit appearance events (fields first seen after line 1)
		for (i = 1; i <= fields_n; i++) {
			f = field_order[i]
			if (field_first_line[f] > first_record_line) {
				printf("{\"type\":\"field_appeared\",\"field\":\"%s\",\"line\":%d,\"value_type\":\"%s\"}\n",
					json_escape(f), field_first_line[f], json_escape(field_first_type[f]))
			}
		}

		# Emit disappearance events (fields not seen on the last processed record line)
		for (i = 1; i <= fields_n; i++) {
			f = field_order[i]
			if (field_last_line[f] < last_record_line) {
				printf("{\"type\":\"field_disappeared\",\"field\":\"%s\",\"last_line\":%d,\"last_type\":\"%s\"}\n",
					json_escape(f), field_last_line[f], json_escape(field_last_type[f]))
			}
		}

		# Emit type-change events (in the order observed)
		for (i = 1; i <= type_changes_n; i++) {
			printf("{\"type\":\"type_changed\",\"field\":\"%s\",\"line\":%d,\"from\":\"%s\",\"to\":\"%s\"}\n",
				json_escape(type_change_field[i]),
				type_change_line[i],
				json_escape(type_change_from[i]),
				json_escape(type_change_to[i]))
		}

		printf("{\"type\":\"summary\",\"lines\":%d,\"records\":%d,\"fields\":%d}\n", total_lines, records, fields_n)
		exit 0
	}
}
