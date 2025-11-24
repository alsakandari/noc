package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:os"
import "core:reflect"
import "core:strings"

Language :: enum {
	C,
	CPP,
	Rust,
	Odin,
	JavaScript,
	TypeScript,
	Markdown,
}

Stat :: struct {
	files: int,
	code:  int,
	blank: int,
}

Accumulation :: struct {
	by_language:   map[Language]Stat,
	sum:           Stat,
	ignored_files: int,
}

accumulate :: proc(dir_path: string, accumulation: ^Accumulation) {
	dir, open_err := os.open(dir_path)

	if open_err != nil {
		fmt.eprintln("error: could not open directory:", dir_path)
		os.exit(1)
	}

	if !os.is_dir(dir) {
		fmt.eprintln("error: not a directory:", dir_path)
		os.exit(1)
	}

	files, read_err := os.read_dir(dir, 0)

	if read_err != nil {
		fmt.eprintln("error: could not read directory:", dir_path)
		os.exit(1)
	}

	defer free(raw_data(files))

	for file in files {
		if file.is_dir {
			accumulate(file.fullpath, accumulation)

			continue
		}

		language: Language

		if strings.ends_with(file.name, ".odin") {
			language = .Odin
		} else if strings.ends_with(file.name, ".md") {
			language = .Markdown
		} else if strings.ends_with(file.name, ".c") || strings.ends_with(file.name, ".h") {
			language = .C
		} else if strings.ends_with(file.name, ".cpp") || strings.ends_with(file.name, ".hpp") {
			language = .CPP
		} else {
			accumulation.ignored_files += 1

			continue
		}

		file_bytes, read_file_success := os.read_entire_file(file.fullpath)

		if !read_file_success {
			fmt.eprintln("error: could not read file:", file.fullpath)
			os.exit(1)
		}

		file_content := string(file_bytes)

		file_lines := strings.split_lines(file_content)

		code := 0
		blank := 0

		for line, i in file_lines {
			has_code := false

			for ch in line {
				if !strings.is_space(ch) {
					has_code = true
					break
				}
			}

			if has_code {
				code += 1
			} else {
				blank += 1
			}
		}

		_, stat, _, _ := map_entry(&accumulation.by_language, language)

		stat.code += code
		stat.blank += blank
		stat.files += 1

		accumulation.sum.code += code
		accumulation.sum.blank += blank
		accumulation.sum.files += 1
	}
}

digits_count :: proc(n: $T) -> int where intrinsics.type_is_numeric(T) {
	return int(math.floor(math.log10(f64(n)))) + 1
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage:", os.args[0], "<directory>")
		os.exit(1)
	}

	accumulation: Accumulation

	accumulate(os.args[1], &accumulation)

	max_language_padding := 0

	for language, _ in accumulation.by_language {
		language_padding := len(reflect.enum_field_names(Language)[language])

		if language_padding > max_language_padding {
			max_language_padding = language_padding
		}
	}

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	fmt.printfln(
		"language%*sfiles%*sblank%*scode",
		25 - len("language"),
		"",
		25 - len("files"),
		"",
		25 - len("blank"),
		"",
	)

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	for language, stat in accumulation.by_language {
		language_name := reflect.enum_field_names(Language)[language]

		fmt.printfln(
			"%s%*s%d%*s%d%*s%d",
			language_name,
			25 - len(language_name),
			"",
			stat.files,
			25 - digits_count(stat.files),
			"",
			stat.blank,
			25 - digits_count(stat.blank),
			"",
			stat.code,
		)
	}

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	fmt.printfln(
		"Sum:%*s%d%*s%d%*s%d",
		25 - len("Sum:"),
		"",
		accumulation.sum.files,
		25 - digits_count(accumulation.sum.files),
		"",
		accumulation.sum.blank,
		25 - digits_count(accumulation.sum.blank),
		"",
		accumulation.sum.code,
	)
}
