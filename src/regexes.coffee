
'use strict'

############################################################################################################
GUY                       = require 'guy'


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



#-----------------------------------------------------------------------------------------------------------
@rx =
  chrs:
    strict:
      allowed:
        head:     /// [        A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
        tail:     /// [  $ 0-9 A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
      forbidden:
        head:     /// [  \x00-\x2f           \x3a-\x40 \x5b-\x5e \x60 \x7b-\x7f ] ///u
        tail:     /// [  \x00-\x23 \x25-\x2f \x3a-\x40 \x5b-\x5e \x60 \x7b-\x7f ] ///u
        paren:    /// [  ( $ 0-9 A-Z _ a-z \u{0080}-\u{10ffff}  ] ///u
    practical:
      allowed:
        head:     /// [        A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u
        tail:     /// [  $ 0-9 A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u
      forbidden:
        head:     /// [  \x00-\x2f           \x3a-\x40 \x5b-\x5e \x60 \x7b-\xa0 ] ///u
        tail:     /// [  \x00-\x23 \x25-\x2f \x3a-\x40 \x5b-\x5e \x60 \x7b-\xa0 ] ///u
        paren:    /// [  ( $ 0-9 A-Z _ a-z \u{00a1}-\u{10ffff}  ] ///u

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_any_name = ( cfg ) -> ///
  # (?<! #{cfg._escape_esc} )
  #{cfg._prefix_esc}
  #{@rx.chrs[ cfg.mode ].allowed.head.source}
  #{@rx.chrs[ cfg.mode ].allowed.tail.source}*
  ///sgu

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_bare_name = ( cfg ) -> ///
  # (?<! #{cfg._escape_esc} )
  #{cfg._prefix_esc}
  #{@rx.chrs[ cfg.mode ].allowed.head.source}
  #{@rx.chrs[ cfg.mode ].allowed.tail.source}*
  (?! #{@rx.chrs[ cfg.mode ].forbidden.paren.source} )
  ///sgu

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_paren_name = ( cfg ) -> ///
  # (?<! #{cfg._escape_esc} )
  #{cfg._prefix_esc}
  #{@rx.chrs[ cfg.mode ].allowed.head.source}
  #{@rx.chrs[ cfg.mode ].allowed.tail.source}*
  (?= [(] )
  ///sgu

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_start_paren_name = ( cfg ) -> ///
  ^
  #{cfg._prefix_esc}
  #{@rx.chrs[ cfg.mode ].allowed.head.source}
  #{@rx.chrs[ cfg.mode ].allowed.tail.source}*
  (?= [(] )
  ///u

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_parameter = ( cfg, parameter ) -> ///
  (?<! #{cfg._escape_esc} )
  #{GUY.str.escape_for_regex parameter}
  (?: (?! #{@rx.chrs[ cfg.mode ].forbidden.paren.source} ) )
  ///gu

#-----------------------------------------------------------------------------------------------------------
@get_rx_for_escaped_prefix = ( cfg ) -> /// #{cfg._escape_esc} #{cfg._prefix_esc} ///gu
@get_rx_for_escaped_escape = ( cfg ) -> /// (?<esc> #{cfg._escape_esc}+ ) ///gu


