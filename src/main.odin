package main

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:os"
import "core:reflect"
import "core:strings"

Language :: enum {
	Ada,
	B,
	Bat,
	Bash,
	Barq,
	C,
	C3,
	CPP,
	Fish,
	JavaScript,
	JSON,
	Markdown,
	Nur,
	Odin,
	Rust,
	TypeScript,
	TOML,
	YAML,
  Python,
  OCAML,
}

Paths :: struct {
  ignore_list: [dynamic]string,
  count_list: [dynamic]string
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

human_num :: proc(num: int) -> string {
  num := f32(num)
  switch {
  case 1000 <= num && num <1_000_000: return fmt.tprintf("%.1f K", num/1000)

  case 1_000_000 <= num && num <1_000_000_000: return fmt.tprintf("%.1f M", num/1_000_000)

  case num >= 1_000_000_000: return fmt.tprintf("%.1f B \n P.S. This is way too many lines you should rethink your life choices", num/1_000_000_000)

  case: return fmt.tprintf("%.f", num)
  }
}

accumulate :: proc(dir_path: string, accumulation: ^Accumulation, path_lists: ^Paths) {
	dir, open_err := os.open(dir_path)

	if open_err != nil {
		fmt.eprintln("error: could not open directory:", dir_path)
		os.exit(1)
	}

	if !os.is_dir(dir) {
		fmt.eprintln("error: not a directory:", dir_path)
		os.exit(1)
	}

	defer os.close(dir)

	files, read_err := os.read_dir(dir, 0)

	if read_err != nil {
		fmt.eprintln("error: could not read directory:", dir_path)
		os.exit(1)
	}

	defer free(raw_data(files))

	for file in files {

    in_ignore_list := false
    for path in path_lists.ignore_list {
      if path == file.fullpath {
        in_ignore_list = true
        break
      }
    }

    in_count_list := false
    for path in path_lists.count_list {
      if path == file.fullpath {
        in_count_list = true
        break
      }
    }

    if in_ignore_list {
			accumulation.ignored_files += 1

			continue
    }

		if file.is_dir {
      if file.name[0] ==  '.' && !in_count_list { continue }

			accumulate(file.fullpath, accumulation, path_lists)
			continue
		}

		language: Language

		if strings.ends_with(file.name, ".ada") {
			language = .Ada
		} else if strings.ends_with(file.name, ".odin") {
			language = .Odin
		} else if strings.ends_with(file.name, ".js") ||
		   strings.ends_with(file.name, ".cjs") ||
		   strings.ends_with(file.name, ".mjs") ||
		   strings.ends_with(file.name, ".jsx") {
			language = .JavaScript
		} else if strings.ends_with(file.name, ".ts") ||
		   strings.ends_with(file.name, ".cts") ||
		   strings.ends_with(file.name, ".mts") ||
		   strings.ends_with(file.name, ".tsx") {
			language = .TypeScript
		} else if strings.ends_with(file.name, ".b") {
			language = .B
		} else if strings.ends_with(file.name, ".bat") {
			language = .Bat
		} else if strings.ends_with(file.name, ".bq") {
			language = .Barq
		} else if strings.ends_with(file.name, ".sh") {
			language = .Bash
		} else if strings.ends_with(file.name, ".fish") {
			language = .Fish
		} else if strings.ends_with(file.name, ".c") || strings.ends_with(file.name, ".h") {
			language = .C
		} else if strings.ends_with(file.name, ".c3") || strings.ends_with(file.name, ".c3i")|| strings.ends_with(file.name, ".c3t") {
			language = .C3
		} else if strings.ends_with(file.name, ".cpp") || strings.ends_with(file.name, ".hpp") {
			language = .CPP
		} else if strings.ends_with(file.name, ".rs") {
			language = .Rust
		} else if strings.ends_with(file.name, ".md") {
			language = .Markdown
		} else if strings.ends_with(file.name, ".nur") {
			language = .Nur
		} else if strings.ends_with(file.name, ".json") {
			language = .JSON
		} else if strings.ends_with(file.name, ".toml") {
			language = .TOML
		} else if strings.ends_with(file.name, ".yaml") || strings.ends_with(file.name, ".yml") {
			language = .YAML
		} else if strings.ends_with(file.name, ".py") {
			language = .Python
		} else if strings.ends_with(file.name, ".ml") {
			language = .OCAML
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
	if n == 0 do return 1
	return int(math.floor(math.log10(f64(n)))) + 1
}

PADDING :: 25

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage:", os.args[0], "<..directories>", "[-i] <files/directories to ignore>")
		os.exit(1)
	}

  cwd := os.get_current_directory();

  path_lists: Paths

	accumulation: Accumulation

  h_flag: bool = false
  i_flag: bool = false

	for arg in os.args[1:] {
    if arg == "-i" { i_flag = true; continue}

    if !h_flag && !i_flag {
      append(&path_lists.count_list, arg)

    } else if i_flag {
      fullpath := fmt.tprintf("%s/%s", cwd, arg)
      append(&path_lists.ignore_list, fullpath)
    }
  }

  for dir_path in path_lists.count_list[0:] {
    accumulate(fmt.tprintf("%s/%s", cwd, dir_path), &accumulation, &path_lists)
  }

	fmt.println("ignored", accumulation.ignored_files, "files")

	fmt.println()

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	fmt.printfln(
		"language%*sfiles%*sblank%*scode",
		PADDING - len("language"),
		"",
		PADDING - len("files"),
		"",
		PADDING - len("blank"),
		"",
	)

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	for language, stat in accumulation.by_language {
		language_name := reflect.enum_field_names(Language)[language]

		fmt.printfln(
			"%s%*s%s%*s%s%*s%s",
			language_name,
			PADDING - len(language_name),
			"",
			human_num(stat.files),
			PADDING - len(human_num(stat.files)),
			"",
			human_num(stat.blank),
			PADDING - len(human_num(stat.blank)),
			"",
			human_num(stat.code),
		)
	}

	fmt.println(
		"------------------------------------------------------------------------------------------",
	)

	fmt.printfln(
		"Sum:%*s%s%*s%s%*s%s",
		PADDING - len("Sum:"),
		"",
		human_num(accumulation.sum.files),
		PADDING - len(human_num(accumulation.sum.files)),
		"",
		human_num(accumulation.sum.blank),
		PADDING - len(human_num(accumulation.sum.blank)),
		"",
		human_num(accumulation.sum.code),
	)
}
