package hlx.runtime;

/** HLX's public hook control enum, mirrored for interpreter boundary tests. */
enum HlxPrefixResult<T> {
    Continue;
    Skip;
    SkipWith(result:T);
}
