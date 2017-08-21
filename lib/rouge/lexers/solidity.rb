# -*- coding: utf-8 -*- #

module Rouge
  module Lexers
    class Solidity < RegexLexer
      tag 'solidity'
      filenames '*.sol', '*.solidity'
      mimetypes 'text/solidity'

      title "Solidity"
      desc "Solidity, an Ethereum smart contract programming language"

      # optional comment or whitespace
      ws = %r((?:\s|//.*?\n|/[*].*?[*]/)+)
      id = /[a-zA-Z_][a-zA-Z0-9_]*/


      def self.analyze_text(text)
        return 1 if text.shebang? 'pragma solidity'
      end

      def self.keywords
        @keywords ||= Set.new %w(
          anonymous as assembly break constant continue contract do
          else enum event external for function hex if indexed interface
          internal import is library mapping memory modifier new payable
          public pragma private return returns storage struct throw
          using var while

          delete
        )
      end

      def self.constants
        @constants ||= Set.new %w(
          wei finney szabo ether
          seconds minutes hours days weeks years
        )
      end

      def self.keywords_type
        @keywords_type ||= Set.new %w(
          int uint address bool
        )
        # TODO: {int,uint,bytes,fixed,ufixed}{MxN}
      end

      def self.reserved
        @reserved ||= Set.new %w(
          abstract after case catch default final in inline let
          match null of pure relocatable static switch try type
          typeof view
        )
      end

      def self.builtins
        @builtins ||= []
      end

      start { push :bol }

      state :expr_bol do
        mixin :inline_whitespace

        rule(//) { pop! }
      end

      # :expr_bol is the same as :bol but without labels, since
      # labels can only appear at the beginning of a statement.
      state :bol do
        rule /#{id}:(?!:)/, Name::Label
        mixin :expr_bol
      end

      state :inline_whitespace do
        rule /[ \t\r]+/, Text
        rule /\\\n/, Text # line continuation
        rule %r(/(\\\n)?[*].*?[*](\\\n)?/)m, Comment::Multiline
      end

      state :whitespace do
        rule /\n+/m, Text, :bol
        rule %r(//(\\.|.)*?\n), Comment::Single, :bol
        mixin :inline_whitespace
      end

      state :expr_whitespace do
        rule /\n+/m, Text, :expr_bol
        mixin :whitespace
      end

      state :statements do
        mixin :whitespace
        rule /(hex)?\"/, Str, :string_double
        rule /(hex)?\'/, Str, :string_single
        rule %r((u8|u|U|L)?'(\\.|\\[0-7]{1,3}|\\x[a-f0-9]{1,2}|[^\\'\n])')i, Str::Char
        rule /0x[0-9a-f]+[lu]*/i, Num::Hex
        rule /0[0-7]+[lu]*/i, Num::Oct
        rule /\d+[lu]*/i, Num::Integer
        rule %r(\*/), Error
        rule %r([~!%^&*+=\|?:<>/-]), Operator
        rule /[()\[\],.]/, Punctuation
        rule /\bcase\b/, Keyword, :case
        rule /(?:true|false|NULL)\b/, Name::Builtin
        rule id do |m|
          name = m[0]

          if self.class.keywords.include? name
            token Keyword
          elsif self.class.keywords_type.include? name
            token Keyword::Type
          elsif self.class.constants.include? name
            token Keyword::Constant
          elsif self.class.reserved.include? name
            token Keyword::Reserved
          elsif self.class.builtins.include? name
            token Name::Builtin
          else
            token Name
          end
        end
      end

      state :root do
        mixin :expr_whitespace

        # functions
        rule %r(
          ([\w*\s]+?[\s*]) # return arguments
          (#{id})          # function name
          (\s*\([^;]*?\))  # signature
          (#{ws})({)         # open brace
        )mx do |m|
          # TODO: do this better.
          recurse m[1]
          token Name::Function, m[2]
          recurse m[3]
          recurse m[4]
          token Punctuation, m[5]
          push :function
        end

        # function declarations
        rule %r(
          ([\w*\s]+?[\s*]) # return arguments
          (#{id})          # function name
          (\s*\([^;]*?\))  # signature
          (#{ws})(;)       # semicolon
        )mx do |m|
          # TODO: do this better.
          recurse m[1]
          token Name::Function, m[2]
          recurse m[3]
          recurse m[4]
          token Punctuation, m[5]
          push :statement
        end

        rule(//) { push :statement }
      end

      state :statement do
        rule /;/, Punctuation, :pop!
        mixin :expr_whitespace
        mixin :statements
        rule /[{}]/, Punctuation
      end

      state :function do
        mixin :whitespace
        mixin :statements
        rule /;/, Punctuation
        rule /{/, Punctuation, :function
        rule /}/, Punctuation, :pop!
      end

      state :string_common do
        rule /\\(u[a-fA-F0-9]{4}|x..|[^x])/, Str::Escape
        rule /[^\\\"\'\n]+/, Str
        rule /\\\n/, Str # line continuation
        rule /\\/, Str # stray backslash
      end

      state :string_double do
        mixin :string_common
        rule /"/, Str, :pop!
        rule /\'/, Str
      end

      state :string_single do
        mixin :string_common
        rule /'/, Str, :pop!
        rule /\"/, Str
      end
    end
  end
end
