#!/usr/bin/ruby

require 'rubygems'
require 'nokogiri'
require 'net/https'
require 'net/http'

class Pastebin
  @@post_url = URI.parse 'http://pastebin.com/api/api_post.php'
  @@login_url = URI.parse 'http://pastebin.com/api/api_login.php'

  def secure_http(url)
    secure_url = URI.parse(url.gsub(/http:/, 'https'))
    conn = Net::HTTP.new(secure_url.host, secure_url.port)
    conn.use_ssl = true
    # don't require CA verification on our side.
    conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
    yield conn
  end

  def initialize(args)
    #secure_http @@login_url do |http|
    resp, data = Net::HTTP.post_form(@@login_url, args)
    if resp.code_type == Net::HTTPOK
      @userkey = data
      @api_key = args[:api_dev_key]
    else
      raise RuntimeError, data
    end
  end

  def paste(name, code)
    format = case name
               # pastebin knows how to do hiliting for these:
             when /\.rb$/ then 'ruby'
             when /\.css$/ then 'css'
             when /\.txt$/ then 'text'
             when /\.xml$/ then 'xml'
             when /\.html$/ then 'html4strict'
             when /\.sh$/ then 'bash'
             when /\.sql$/ then 'sql'
               # hacks: pastebin lacks built-in hiliting for these:
             when /\.html\.haml$/ then 'ruby'
             when /\.html\.erb$/ then 'html4strict'
             when /\.feature$/ then 'text'
               # everything else
             else 'text'
             end
    args = {
      :api_option => 'paste',
      :api_dev_key => @api_key,
      :api_user_key => @userkey,
      :api_paste_code => code,
      :api_paste_name => name,
      :api_paste_expire_date => 'N', # never expire
      :api_paste_private => '0', # public
      :api_paste_format => format,
    }
    return do_cmd(args, /^https?:\/\/pastebin.com/, name )
  end

  def delete(id)
    args = {
      :api_dev_key => @api_key,
      :api_user_key => @userkey,
      #:api_paste_key => "http://pastebin.com/#{id}",
      :api_paste_key => id,
      :api_option => 'delete',
    }
    return do_cmd(args, /removed/i, id)
  end

  def list
    args = {
      :api_dev_key => @api_key,
      :api_user_key => @userkey,
      :api_results_limit => 1000, # max allowed
      :api_option => 'list'
    }
    return nil unless xml = do_cmd(args, /^<paste>/, 'list')
    Nokogiri::XML::Document.parse('<pastes>' << xml << '</pastes>').
      xpath('//paste/paste_key').
      map(&:content)
  end
  
  def paste_file(filename)
    begin
      postname = File.basename(filename)
      content = IO.read(filename)
      self.paste(postname, content)
    rescue Exception => e
      puts "Warning: posting file '#{filename}': #{e.message}"
      nil
    end
  end

  private

  def do_cmd(args, success_regex, name='')
    resp = Net::HTTP.post_form(@@post_url, args)
    if resp.code_type == Net::HTTPOK && resp.body =~ success_regex
      resp.body
    else
      puts "Warning: posting '#{name}': response #{resp.code} : #{resp.body}"
      nil
    end
  end
end
