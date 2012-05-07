#!/usr/bin/ruby

require 'rubygems'
require 'nokogiri'

doc = Nokogiri::HTML::Document.parse(IO.read(ARGV[0]), nil, 'ISO-8859-1')


# last row of actual text TABLES seems to contain a single TD with empty whitespace
doc.xpath("//table[count(tr)>1]/tr[count(td)=1]/td[.='']").remove

# empty table rows cause some tables to not render at all
doc.xpath("//tr[count(td)=0]").remove

# for some reason figures are wrapped in <div align="center"><table><tr><td>...</td></tr></table></div>
# and this prevents figures that are tables from rendering properly.
doc.xpath("//div[not(@class)]/table[count(tr)=1]/tr[count(td)=1]/td").each do |node|
  topdiv = node.parent.parent.parent
  node.children.each { |child| topdiv.add_previous_sibling(child) }
  topdiv.remove
end

# turn chapter anchors from this:  <h2 class='chapter_name|appendixHead'><i>1. <a name='xx'></a> Chapter Name</i></h2>
#                      into this:  <a name='xx'><h2><i>1. Chapter Name</i></h2></a>

# first wrap each <h2> in the <a>
doc.xpath("//h2/i/a").each do |node|
  anchor_name = node.get_attribute 'name'
  # reparent the <h2> by putting <a> around it
  h2 = node.parent.parent
  h2.swap("<a name=\"#{anchor_name}\">#{h2}</a>")
end
# then remove the spurious <a></a> inside the h2's
doc.xpath("//h2/i/a").each { |node| node.remove }

# same thing for <h3> (section heads)
doc.xpath("//h3/a").each do |node|
  anchor_name = node.get_attribute 'name'
  # reparent the <h3>
  h3 = node.parent
  h3.swap("<a name=\"#{anchor_name}\">#{h3}</a>")
end
# then remove spurious <a></a> inside <h3>
doc.xpath("//h3/a").each { |node| node.remove }

# add line numbers to all inline code examples
doc.xpath("//pre[@class='code']").each do |node|
  # ugh - tex4ht puts stray </p> INSIDE <pre>, so nokogiri turns that
  # into <pre> <p> content </p> </pre> - we need to get rid of <p>
  if (inner_par = node.xpath('p'))
    node.inner_html = inner_par.inner_html
    inner_par.remove
  end
  lines = node.inner_text.gsub(/\A\s*\n/m, '').split("\n")
  node.content = "\n" + (1..lines.length).zip(lines).map { |n| sprintf("%2d%s", *n) }.join("\n") + "\n"
end

# generate html
html = doc.to_xhtml(:encoding => 'ISO-8859-1')

# tex4ht outputs an apparently-random-length string of underscores to
#  render \hrule in LaTeX, so if we see >8 of them, replace with <hr> tag
html.gsub!(/_______+/, '<hr>')

# anywhere that we have two <hr> in a row with only an anchor in between,  delete one <hr>
# BEFORE:  <hr><a name="x1-70022"></a><hr>
# AFTER:   <hr><a name="x1-70022"></a>
html.gsub!(/<hr(?: \/)?>\s*(<a[^<]+<\/a>)?\s*(<!--l.\s+\d+--><p>\s*<\/p>)?\s*<hr(?: \/)?>/, '<hr>\1')

# some TeX markup that mistakenly gets included in t4ht output:
# BEFORE: \protect \relax \special {t4ht=<tt>}self.title\relax \special {t4ht=</tt>} 
# AFTER:  <tt>self.title</tt>

html.gsub!(/(?:\\protect)?\s*\\relax\s*\\special\s*\{t4ht=([^}]+)\}/, ' \1 ')

# god only knows where the hell this comes from:
# BEFORE: \protect \unhbox \voidb@x {\unhbox \voidb@x \special {t4ht@95}x}
# AFTER: _
html.gsub!('\protect \unhbox \voidb@x {\unhbox \voidb@x \special {t4ht@95}x}', '_')

# 'nowrap' tag inserted by tex4ht makes tables unrenderable on kindle
html.gsub!(/\s+nowrap>/, '>')

# xml-to-html somehow mangles <mbp:pagebreak> to just <pagebreak>
html.gsub!('<pagebreak></pagebreak>', '<mbp:pagebreak/>')


# get rid of stupid and often incorrect codepoints
bad_codepoints = {
#  '8212' => '|',
}
bad_codepoints.each_pair do |k,v|
  html.gsub!(/&\##{k};/, v)
end

# insert <a name="start"> anchor at top of body
html.gsub!(/<body>/, '<body><a name="start">')
puts html
