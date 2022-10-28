
xxx =
  prefix: '@'
###

Character (CHR) regexes (RXs) are divided into two modes:

* `strict` mode keeps close to a practical test against a recent version (3.39) of SQLite. In this test, it
  turned out that SQLite allows all Unicode codepoints greater than `U+007f <control> : DELETE [DEL]` in
  names. This is impratical because all codepoints in the range `U+0080 .. U+00A0` are somehwat obscure
  control codes and the non-breaking space. Therefore, an alternative mode, dubbed
* `practical` mode has been added that excludes these problematic codepoints.
* Each mode is split into two mutually complementary factions, `allowed` and `forbidden`; under these, we
  find
* `head` for the first character and `tail` for the trailing characters in identifiers.
* Additionally, there are two entries in `forbidden.paren`, which list the codepoints in `tail` plus
  `U+0028 Left Parenthesis`, with one entry per mode.
* All codepoint collections...
  * are defined as regular expression literals with the `u`nicode flag set; this provides some level of
    assurance against nonsensical regular expression constructs;
  * are given as positive character classes within a single pair of square brackets.

###
  chrs:
    strict:
      allowed:
        head:     /// [        A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
        tail:     /// [  $ 0-9 A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
      forbidden:
        head:     /// [  \x00-\x2f           \x3a-\x40 \x5b-\x5e \x60 \x7b-\x7f ] ///u
        tail:     /// [  \x00-\x23 \x25-\x2f \x3a-\x40 \x5b-\x5e \x60 \x7b-\x7f ] ///u
        paren:   /// [  ( $ 0-9 A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
    practical:
      allowed:
        head:     /// [        A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u
        tail:     /// [  $ 0-9 A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u
      forbidden:
        head:     /// [  \x00-\x2f           \x3a-\x40 \x5b-\x5e \x60 \x7b-\xa0 ] ///u
        tail:     /// [  \x00-\x23 \x25-\x2f \x3a-\x40 \x5b-\x5e \x60 \x7b-\xa0 ] ///u
        paren:    /// [  ( $ 0-9 A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u

xxx.name = ///
            # (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
            #{xxx.prefix}
            #{xxx.chrs.practical.allowed.head.source}
            #{xxx.chrs.practical.allowed.tail.source}*
            ///sgu
xxx.bare_name = ///
            # (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
            #{xxx.prefix}
            #{xxx.chrs.practical.allowed.head.source}
            #{xxx.chrs.practical.allowed.tail.source}*
            (?! #{xxx.chrs.practical.forbidden.paren.source} )
            ///sgu
xxx.paren_name = ///
            # (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
            #{xxx.prefix}
            #{xxx.chrs.practical.allowed.head.source}
            #{xxx.chrs.practical.allowed.tail.source}*
            (?= [(] )
            ///sgu

module.exports = xxx
