#!/usr/local/bin/ruby -Ke
## Copyright (C) 2005 MITA Yuusuke <clefs@mail.goo.ne.jp>
##
## Author: MITA Yuusuke <clefs@mail.goo.ne.jp>
## Maintainer: SKK Development Team <skk@ring.gr.jp>
## Version: $Id: conjugation.rb,v 1.1 2005/06/05 16:49:32 skk-cvs Exp $
## Keywords: japanese, dictionary
## Last Modified: $Date: 2005/06/05 16:49:32 $
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2, or (at your option)
## any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
## General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program, see the file COPYING.  If not, write to the
## Free Software Foundation Inc., 59 Temple Place - Suite 330, Boston,
## MA 02111-1307, USA.
##
### Commentary:
##
### Instruction:
##
## This script generates (mainly) okuri-ari pairs derived from conjugational
## words given, using annotations designed for this purpose
## (esp. in SKK-JISYO.notes).
##
##     「あいしあu /愛し合;‖ワ行五段[wiueot(c)/」
##
## This pair is developed into:
##
##     「あいしあw /愛し合/」
##     「あいしあi /愛し合/」
##     「あいしあu /愛し合/」
##     「あいしあe /愛し合/」
##     「あいしあo /愛し合/」
##     「あいしあt /愛し合/」
##     「あいしあc /愛し合/」 (if -p option is given)
##
## By default, okuri-nasi pairs with one-letter 'candidate' will be expanded
## in the same manner, eg.:
##
##     「あい /愛;‖サ変名詞[φs]/」
##
##     「あい /愛/」
##     「あいs /愛/」
##
## while -O suppress this kind of expansion, -o option allows it for
## candidates of any length:
##
##     「しんこく /深刻;‖形容動詞[φdns]/」
##
##     「しんこく /深刻/」
##     「しんこくd /深刻;‖形容動詞[φdns]/」
##     「しんこくn /深刻;‖形容動詞[φdns]/」
##     「しんこくs /深刻;‖形容動詞[φdns]/」
##     
##
## skkdictools.rb should be in the loadpath of ruby.

#require 'jcode'
#require 'kconv'
require 'skkdictools'
require 'optparse'
opt = OptionParser.new

$annotation_mode = "all"
$comment_mode = "all"
parentheses = "discard"
okuri_nasi_too = "oneletter"
#okuri_strictly_output = false
purge = false

# 見あげる、見ばえ、見ちゃった、見どころ、見えない、見はらし、見ごたえ、
# 見い出す、見かねる、見まい、見ぬ、見おろす、見っぱなし、見る、見せる、見て、
# 見うしなう、見わける、見よう、見ず。
all_strings = "abcdeghikmnoprstuwyz"

# #にん /#3人/#1人/#0人/#2人/
numerative_order = [3, 1, 0, 2]

# カ変 (くr /来/)
# サ変 (すr /為/)
# ア行下二 (ありうr /有り得/)
IrregularConjugationTable = [
	[ "カ変", "くr",
	[
	    # (く) 来る, 来んな
	    "くr", "くn",
	    # (こ) 来い, 来ない, 来られる, 来させる, 来よう, 来ず
	    "こi", "こn", "こr", "こs", "こy", "こz",
	    # (き) 来ちゃう, 来づらい, 来ます, 来ぬ, 来そう, 来て, 来やがった,
	    # (きえない, きはしない, きいな, きっこない)
	    "きc", "きd", "きm", "きn", "きs", "きt", "きy",
	]],

	[ "サ変", "すr",
	[
	    # (す) 為る, 為まい (,すんな)
	    "すr", "すm",
	    # (し) 為ちゃえ, 為ます, 為ない, 為ろ, 為そう, 為て, 為よう
	    # (,しうる, しづらい)
	    "しc", "しm", "しn", "しr", "しs", "しt", "しy",
	    # (せ) 為よ, 為ず (,せい, せば)
	    "せy", "せz"
	]],

	[ "ア行下二", "うr",
	[
	    # (う) 有り得べし, 有り得る
	      "うb", "うr",
	    # (え) 得ちゃえ, 得ます, 得ない, 得る, 得そう, 得て, 得よう
	      "えc", "えm", "えn", "えr", "えs", "えt", "えy"
	]]
]

def print_pair2(key, candidate, annotation, comment, base = false)
	annotation = nil if $annotation_mode == "none" || ($annotation_mode == "self" && !base)
	comment = nil if $comment_mode == "discard" || ($comment_mode == "self" && !base)

	print_pair(key, candidate, annotation, comment)
end

opt.on('-u', "don't add annotations for derived pairs") { $annotation_mode = "self" }
opt.on('-U', 'eliminate all the annotations') { $annotation_mode = "none" }
opt.on('-c', "don't add comments for derived pairs") { $comment_mode = "self" }
opt.on('-C', 'eliminate all the comments') { $comment_mode = "discard" }
opt.on('-p', "use OKURIs in parentheses too") { parentheses = "use" }
opt.on('-o', "process okuri-nasi pairs too (eg. SAHEN verbs and adjective verbs)") { okuri_nasi_too = "all" }
opt.on('-O', "never process okuri-nasi pairs") { okuri_nasi_too = "none" }
opt.on('-x', 'skip candidates marked with "※" or "?"') { purge = true }

begin
	opt.parse!(ARGV)
rescue OptionParser::InvalidOption => e
	print "'#{$0} -h' for help.\n"
	exit 1
end

while gets
	next if $_ =~ /^;/ || $_ =~ /^$/
	midasi, tokens = $_.parse_skk_entry

	if (/^(>?[ぁ-ん゛]*)([a-z]+)$/ =~ midasi)
		stem = $1
		okuri = $2
	elsif okuri_nasi_too == "none"
		next
	else
		stem = midasi
		okuri = ""
	end

	tokens.each do |token|
		tmp = token.split(";")
		next if tmp[1].nil?
		word = tmp[0]
		next if okuri.empty? && okuri_nasi_too == "oneletter" && word.length > 2
		tmp = tmp[1].split("‖", 2)
		next if tmp[1].nil?
		annotation = tmp[0]
		comment = tmp[1]
		next if purge && annotation =~ /※/
		next if purge && annotation =~ /\?$/

		new_index = 0
		while index = (comment[new_index .. -1] =~ /\[([^\]]*)\]/)
			old_index = new_index
			new_index += index + $1.length + 2
			derivation = $1
			if parentheses == "discard"
				derivation.gsub!(/\([^)]*\)/, '')
			else
				derivation.gsub!(/[()]/, '')
			end

			if derivation == "a-z"
				derivation = all_strings 
			elsif derivation == "*"
				IrregularConjugationTable.each do |table|
					next if !comment[old_index .. new_index].include?(table[0])
					core = midasi.sub(table[1], '')
					next if core == midasi # alternation failed

					table[2].each do |tail|
						new_midasi = "#{core}#{tail}"
						print_pair2(new_midasi, word, annotation, comment,
						(new_midasi == midasi))
					end
					break
				end
				next
			end

			if derivation.gsub!(/φ/, '')
				print_pair2(stem, word, annotation, comment, (okuri == ""))
			end

			# (quasi-)suffix
			if derivation.gsub!(/</, '')
				print_pair2(">#{stem}", word, annotation, comment, false)
			end

			# numerative
			if derivation.gsub!(/#/, '')
				for i in numerative_order
					print_pair2("##{stem}", "##{i}#{word}", annotation, comment, false)
				end
			end

			derivation.delete("^a-z>").each_byte do |byte|
				new_okuri=byte.chr
				print_pair2("#{stem}#{new_okuri}", word, annotation, comment,
				(okuri == new_okuri))
			end
		end
	end
end
