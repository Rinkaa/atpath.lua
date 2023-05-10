# atpath.lua

Access values deep inside modules and tables, using path strings.

## API

### v = atpath.at(t, path)
Use a relative path `"<key1/<key2>/.../<keyN>"` look for the value in the table at the path.
e.g. when t is `t` and path is "a/b/c", it means looking for `t.a.b.c`.

### v = atpath.at_module(path)
Use an absolute path `"/<modulename>/<key1>/<key2>/.../<keyN>"`, to search for a module and then look for the value at the path.
e.g. when path is "/30log/new", it means looking for `require("30log").new`.
Note there is a slash at the beginning; this slash is not omittable.

### keys = atpath.parse(path)
Give the parsed result from a path.
Also `keys.is_absolute` shows whether the path is an absolute path, otherwise a relative path.

### path = atpath.build(keys, modulename?, i?, j?)
Build a path from a array of keys.
If given a `modulename`, prepend it to the path and make it an absolute path.
Use `i` and `j` to specify a range in the array of `keys`.

## Notes

- "." and ".." are supported in the path, meaning "current layer" and "one layer upper" respectively.
    - If a ".." goes up beyond the top layer, an error is thrown.
- If a segment of the path is exactly convertable to a number using `tonumber`, it is regarded as a number.
- If a segment of the path is exactly "true" or "false", it is regarded as a boolean with said value.
- Use ' or " to quote a literal key that prevent any type conversions.
- Use "%xx" in hexadecimal escape format to represent special characters, i.e. "%27" to represent an actual "'" character in the path.

## License

MIT

