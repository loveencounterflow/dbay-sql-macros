(function() {
  var xxx;

  xxx = {
    prefix: '@',
    chrs: {
      strict: {
        allowed: {
          head: /[A-Z_a-z\u{0080}-\u{10ffff}]/u,
          tail: /[$0-9A-Z_a-z\u{0080}-\u{10ffff}]/u
        },
        forbidden: {
          head: /[\x00-\x2f\x3a-\x40\x5b-\x5e\x60\x7b-\x7f]/u,
          tail: /[\x00-\x23\x25-\x2f\x3a-\x40\x5b-\x5e\x60\x7b-\x7f]/u,
          paren: /[($0-9A-Z_a-z\u{0080}-\u{10ffff}]/u
        }
      },
      practical: {
        allowed: {
          head: /[A-Z_a-z\u{00a1}-\u{10ffff}]/u,
          tail: /[$0-9A-Z_a-z\u{00a1}-\u{10ffff}]/u
        },
        forbidden: {
          head: /[\x00-\x2f\x3a-\x40\x5b-\x5e\x60\x7b-\xa0]/u,
          tail: /[\x00-\x23\x25-\x2f\x3a-\x40\x5b-\x5e\x60\x7b-\xa0]/u,
          paren: /[($0-9A-Z_a-z\u{00a1}-\u{10ffff}]/u
        }
      }
    }
  };

  xxx.name = RegExp(`${xxx.prefix // (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
}${xxx.chrs.practical.allowed.head.source}${xxx.chrs.practical.allowed.tail.source}*`, "sgu");

  xxx.bare_name = RegExp(`${xxx.prefix // (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
}${xxx.chrs.practical.allowed.head.source}${xxx.chrs.practical.allowed.tail.source}*(?!${xxx.chrs.practical.forbidden.paren.source})`, "sgu");

  xxx.paren_name = RegExp(`${xxx.prefix // (?<= ^ | #{xxx.chrs.practical.forbidden.head.source} )
}${xxx.chrs.practical.allowed.head.source}${xxx.chrs.practical.allowed.tail.source}*(?=[(])`, "sgu");

  module.exports = xxx;

}).call(this);

//# sourceMappingURL=regexes.js.map