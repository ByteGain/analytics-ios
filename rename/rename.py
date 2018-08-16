# Replace all non-filename references to a word (not containing a .filetype) in all files of
# specified type in a file tree with a new expression

from os import walk
from os.path import dirname, join, abspath, splitext


def replace(dirpath, old_word, new_word, filetypes, changelog_path):
    with open(changelog_path, "a") as changelog:
        dirdata = walk(dirpath)

        for (top_dir, subdirs, file_names) in dirdata.__iter__():
            for file_name in file_names:
                if splitext(file_name)[1] in filetypes:
                    filepath = join(top_dir, file_name)
                    changelog.write(filepath + "\n")

                    with open(filepath, "r") as f:
                        lines = []
                        for line in f:
                            if old_word in line and not line.startswith("#import"):
                                lines.append(line.replace(old_word, new_word))
                                changelog.write("\tReplaced: " + line)
                                changelog.write("\tWith: " + line.replace(old_word, new_word))
                            else:
                                lines.append(line)
                    with open(join(top_dir, file_name), "w") as f:
                        f.writelines(lines)


def __valid_word(word, old_word, filetypes):
    for filetype in filetypes:
        if filetype in word:
            return False

    return old_word in word


# do
# replace(".", "SEGMENT", "BYTEGAIN", [".h", ".m"], abspath("./changelog.txt"))
# replace(".", "SEG", "ByteGain", [".h", ".m"], abspath("./changelog.txt"))
# Undo
replace(".", "BYTEGAIN", "SEGMENT", [".h", ".m"], abspath("./changelog.txt"))
replace(".", "ByteGain", "SEG", [".h", ".m"], abspath("./changelog.txt"))
# replace(dirname(abspath(".")), "BYTEGAIN", "SEGMENT", [".h", ".m"], abspath("./changelog.txt"))
# replace(dirname(abspath(".")), "ByteGain", "SEG", [".h", ".m"], abspath("./changelog.txt"))

