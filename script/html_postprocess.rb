#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'

def warn(str)
  $stderr.puts str
end

theuniquechapter = 0
ARGV.each do |filename|
  begin
    doc = Nokogiri::HTML::Document.parse(IO.read(filename))
    # preamble = Nokogiri::HTML::DocumentFragment.parse(IO.read('html_preamble.html'))

    warn "#{filename}"

    # get rid of all crosslinks
    s = doc.xpath("//div[@class='crosslinks']").remove
    warn "  #{s.length} crosslink div's removed"

    # get rid of tail links
    s = doc.xpath("//p/a[starts-with(@id,'tail')]").remove
    warn "  #{s.length} tail links removed"

    # get rid of tex4ht-generated TOCs
    if (toc = doc.at_css('div#tableofcontents'))
      toc.remove
      warn "  Table of contents removed"
    end
    
    case filename
    when /htmlch/ # chapter
      thechapternum = doc.at_css('h2.chapterhead').content.gsub(/[^0-9]/,'')
      thechapter = "Chapter #{thechapternum}"
    when /htmlli/ # unnumbered chapter (foreword, etc)
      thechapternum = theuniquechapter
      thechapter = doc.at_css('h2.chapterhead').content
      # tex4ht puts id="section_0.0" for all unnumbered secs and
      #   "chapter_0" for all unnumbered chapters, so fix that
      doc.at_css('div#chapter_0').set_attribute 'id', "chapter_#{theuniquechapter}"
      theuniquechapter += 1
      thesec = 1
      doc.xpath("//div[@data-role='page']").each do |sectiondiv|
        if sectiondiv.get_attribute('id') =~ /0\.0/
          sectiondiv.set_attribute 'id', "section_#{theuniquechapter}.#{thesec}"
          thesec += 1
        end
      end
    when /htmlap/ # appendix
      thechapter = doc.at_css('h2.chapterhead').content
      thechapter =~ /^\s*(\w)/
      thechapternum = $1
    end

    warn "  chapter number: #{thechapternum}  name: #{thechapter}"

    # insert Preamble inside <head>
    # doc.at_css('head').add_child(preamble)
    # warn "  HTML preamble inserted"
    

    # delete extraneous css link
    s = doc.xpath("//link[@href='saasbook_html.css']").remove
    warn "  #{s.length} extraneous CSS link removed"

    # change TOC links to point to #toc
    doc.xpath("//a[@href='#x1-1000']").each { |e| e['href'] = '#toc' }

    # get rid of any <p>'s that are direct child of <body>
    s = doc.xpath("//body/p").remove
    warn "  #{s.length} extraneous <p>'s inside <body> removed"

    # last row of every TABLE seems to contain empty whitespace <td>, so just delete entire row
    s = doc.xpath("//table[count(tr)>1]/tr[count(td)=1]/td[.='']").remove
    warn "  #{s.length} weird blank table rows removed"
    
    # removing horizontal rules in tables since they're unsupported in iBooks
    s = doc.xpath("//tr[@class='hline']").remove
    warn "  #{s.length} table rows with horizontal rules removed"
    
    # strip in-book links, since they're unsupported in iBooks
    # s = doc.xpath("//a[starts-with(@href,'#')]")
    s = doc.xpath("//a[not(starts-with(@href,'http')) and contains(@href,'#')]")
    warn "  stripping #{s.length} in-book links"
    s.each { |a| a.replace(a.inner_html) }
    
    # change all the video tags to reference the m4v files because iBooks only supports m4v videos
    doc.xpath("//video[@src]").each { |video| video['src'] = video['src'].sub(".mp4", ".m4v") }
    
    # collect all section links, and put them in every nav footer
    # each should turn into:
    #   <option value="#section_3.1">3.1 Section Name</option>
    # secnumcounter = 1
    # section_navs = Nokogiri::XML::NodeSet.new(doc,
    #   doc.xpath("//h3[@class='sectionhead']").map do |sec|
    #     if sec.content.match( /^\s*(\w+\.\d+)\s+(.*)$/ )
    #       secnum, sectitle = $1,$2
    #     else
    #       secnum = "#{thechapternum}.#{secnumcounter}"
    #       sectitle = sec.content
    #     end
    #     secnumcounter += 1        
    #     option = Nokogiri::XML::Node.new 'option', doc
    #     option.set_attribute 'value', "#section_#{secnum}"
    #     option.content = sec.content
    #     option
    #   end
    #   )
    # warn "  Generated #{section_navs.length} subsection nav elements"
    # optgroups = doc.xpath("//optgroup")
    # warn "  Adding them to #{optgroups.length} nav optgroups"
    # optgroups.each do |optiongroup|
    #   # there must be a nicer way to do this
    #   optiongroup.set_attribute 'label', thechapter
    #   optiongroup.add_child(section_navs.to_html)
    # end
    
    # generate html
    html = doc.to_html
    
    # some TeX markup that mistakenly gets included in t4ht output:
    # BEFORE: \protect \relax \special {t4ht=<tt>}self.title\relax \special {t4ht=</tt>} 
    # AFTER:  <tt>self.title</tt>
    html.gsub!(/(?:\\protect)?\s*\\relax\s*\\special\s*\{t4ht=([^}]+)\}/, ' \1 ')
    
    # tex4ht outputs an apparently-random-length string of underscores to
    #  render \hrule in LaTeX, so if we see >8 of them, replace with <hr> tag
    html.gsub!(/_______+/, '<hr>')

    # get rid of malformed answer and sidebar code
    html.gsub!(/<div class="&lt;span\s+class="\s+cmti-10>answer"&gt;/, '<div>')
    html.gsub!(/<div class="&lt;span\s+class="\s+cmti-10>sidebar"&gt;/, '<div>')
    
    # get rid of stupid and often incorrect codepoints
    bad_codepoints = {
      #  '8212' => '|',
    }
    bad_codepoints.each_pair do |k,v|
      html.gsub!(/&\##{k};/, v)
    end
    File.open(filename, 'w') do |file|
      file.write html
    end
  rescue => e
    warn "EXCEPTION processing #{filename} - preserving original input:\n======\n#{e.message}"
  end
end
