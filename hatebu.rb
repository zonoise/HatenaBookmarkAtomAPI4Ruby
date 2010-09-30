#!/usr/bin/env ruby

require 'uri'
require 'digest/sha1'
require 'base64'
require 'rexml/document'
require 'openssl'
require 'net/http'
require 'pp'
require 'time'

#
# HatenaBookMark AtomAPI への接続とかXMLのパースとか
#
class HatebuAPI
    @username=""
    @password="" 
    @credential_string=""
    @http=""

    #######################################
    #[id]
    #     Hatena id
    #[password]
    #     Hatena Password
    #######################################
    def initialize(id,password)
        username=id
        password=password

        nonce =  OpenSSL::Digest::SHA1.digest(OpenSSL::Digest::SHA1.digest(Time.now.to_s + sprintf("%f", rand()) + $$.to_s))
        created = Time.now.utc.iso8601
        password_digest = Base64.encode64(OpenSSL::Digest::SHA1.digest(
                              nonce + created + password || '')).chop
        @credential_string =
            sprintf %(UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s"),
                    username,password_digest, Base64.encode64(nonce).chop,created
        @http = Net::HTTP.start('b.hatena.ne.jp',80)

    end

    #######################################
    # Get Recent Entries
    #
    # GET /atom/feed 
    #[page_num]
    #    pagenum
    #######################################
    def get_feed(page_num=1)
        page_count=page_num
        path='/atom/feed'
        entries=Array.new
        while 0 < page_count && nil != path
            res=get_single_feed(path)
            #puts res.body
            entries=entries + parse_feed(res.body)
            path = get_next_page(res.body)
            page_count=page_count-1
        end
        return entries
    end

    #######################################
    # Get Rucent Entries by Tag
    # 
    # GET /atom/feed?tag=#{tag}
    #[tag]  tag
    #[page_num] page_num
    #######################################
    def get_feed_by_tag(tag, page_num=1)
        path =URI.encode("/atom/feed?tag=#{tag}")
        #path ="/atom/feed?tag=#{tag}"
        page_count=page_num
        entries=Array.new
        while 0 < page_count && nil != path
            res = @http.get(path,
                 'Accept' => 'application/x.atom+xml, application/xml, text/xml, */*',
                 'X-WSSE'=> @credential_string )
            puts res.body
            entries=entries + parse_feed(res.body)
            path = get_next_page(res.body)
            page_count=page_count-1
            #puts res.body
        end
        return entries
    end

    #######################################
    # Update single entry info
    # 
    # PUT /atom/edit/XXXXX
    #[id]       entry id
    #[summary]  entry summary
    #######################################
    def put_entry(id,summary)
        xml = <<DATA
          <entry xmlns="http://purl.org/atom/ns#">
             <summary type="text/plain"></summary>
          </entry>
DATA

        doc = REXML::Document.new(xml)
        doc.elements['/entry/summary'].add_text(summary)

        # REXML -> String
        data=String.new
        doc.write(data)

        #make request
        path="/atom/edit/#{id}"
        req=Net::HTTP::Put.new(path)
        req['Accept']= 'application/x.atom+xml,application/xml,text/xml,*/*',
        req['X-WSSE']= @credential_string

        #YHAAAA!!!
        res = @http.request(req,data)
        return res
    end

    #######################################
    # Update multi entry info
    # 
    # PUT /atom/edit/XXXXX
    #[entries] Array of Entry Hash
    #######################################
    def put_entries(entries)
        entries.each{|e|
            put_entry(e[:id],e[:summary])
        }
    end

    #######################################
    # Create New Entry
    # return Created Entry ID
    # POST /atom/post
    #[entry] entry hash
    #######################################
    def create_entry(entry)

        # template
        xml = <<DATA 
              <entry xmlns="http://purl.org/atom/ns#">
                  <link rel="related" type="text/html"  />
                  <summary type="text/plain"></summary>
              </entry>
DATA
       
        # edit xml
        doc = REXML::Document.new(xml)
        doc.elements['/entry/link'].add_attribute('href',entry[:url])
        doc.elements['/entry/summary'].add_text(entry[:summary])

        data=String.new 
        doc.write(data)

        #make request
        path='/atom/post'
     
        req=Net::HTTP::Post.new(path)
        req['Accept']= 'application/x.atom+xml,application/xml,text/xml,*/*',
        req['X-WSSE']= @credential_string

        res = @http.request(req,data)
        case res
        when Net::HTTPSuccess then
            return get_edit_url(res.body)
        else
            raise  "Http Response != Success"
        end
    end

    #######################################
    # Get Single Entry
    #
    # GET /atom/edit/#{id}
    #[id] entry id
    #######################################
    def get_entry(id)
        path="/atom/edit/#{id}"
        res = @http.get(path,
                   'Accept' => 'application/x.atom+xml, application/xml, text/xml, */*',
                   'X-WSSE'=> @credential_string )
        #puts res.body
        parse_entry(res.body)

    end

    # Delete Single Entry
    #
    # DELETE /atom/edit/#{id}
    # [id] entry id
    def delete_entry(id)
        path = "/atom/edit/#{id}"
        
        res = @http.delete(path,
                   'Accept' => 'application/x.atom+xml, application/xml, text/xml, */*',
                   'X-WSSE'=> @credential_string )
        case res
        when Net::HTTPSuccess then
            return  res
        else
            raise  "Http Response != Success"
        end
    end

    #----------------------------# 
               private
    #----------------------------#
    
    #  
    #[xml] response body of POST /atom/post 
    #return path
    def get_edit_url(xml)
        doc = REXML::Document.new(xml)
        doc.root.each_element_with_attribute('rel','service.edit'){|link|
         # puts "service.edit #{link.attributes['href']}"
            return link.attributes['href'].split('/').pop
        }
    end

    #######################################
    # path -> xml
    # 与えられたパスから、xmlを返す。
    # つかわないかも
    #######################################
    def get_single_feed(path)
        res = @http.get( path,
               'Accept' => 'application/x.atom+xml, application/xml, text/xml, */*',
               'X-WSSE'=> @credential_string )
        return res
    end

    #######################################
    # xml -> next page url
    # return url
    # if can't exist next page url , return nil
    #######################################
    def get_next_page(xml)
        #次のURLをGET
        doc = REXML::Document.new xml
        next_url=''
        doc.root.each_element_with_attribute('rel','next'){|link|
            next_url= link.attributes['href']
        }
        uri = URI.parse(next_url)
        #次がなければnil返して終了
        if nil == uri.path || nil == uri.query then
            return nil
        end
        return uri.path+"?"+uri.query
    end

    #######################################
    # xml -> array og entry
    # return array of entry
    # each entry is Hash
    # XMLをパースして、エントリ情報の配列を作って園配列を返す
    # エントリ情報はハッシュとして、配列の中には入っています。
    #######################################
    def parse_feed(xml)

        doc = REXML::Document.new xml
        #xmlをパースしてエントリとか必要な情報をゲット
        entries = Array.new
        doc.elements.each('/feed/entry/'){|entry|
            entry_hash = Hash.new  # 1 entry分のハッシュ
            tag_array= Array.new
            tag_string=""
	    
            #title
            entry_hash[:title]=entry.elements['title'].text
            id_text = entry.elements['id'].text
            #文字列をsplitして、idだけをハッシュに格納する
            #tag:hatena.ne.jp,2005:bookmark-zonoise-10062682 -> 10062682
            entry_hash[:id]=id_text.split('-').pop

            entry_hash[:summary]=entry.elements['summary'].text

            #tag  array のほうがいいかも
            entry.elements.each('dc:subject/'){|tag|
                # tag_string=tag_string+ "[#{tag.text}]"
                tag_array.push(tag.text)
            }
            entry_hash[:tag]=tag_array
            entries.push(entry_hash)
        }
        return entries
    end

    #######################################
    # xml -> hash
    #######################################
    def parse_entry(xml)
       entry_hash=Hash.new
       doc = REXML::Document.new xml
       
       entry=doc.elements['entry']
       entry_hash[:title]  = entry.elements['title'].text
       entry_hash[:id]     = entry.elements['id'].text.split('-').pop
       entry_hash[:summary]= entry.elements['summary'].text
       return entry_hash
    end
end

#
# Entries をごにょごにょするメソッドをまとめている
#
module HatebuEntries  
     
    #######################################
    # tagをsummaryにくっつける
    # 編集後の配列を返す
    #######################################
    def marge_summary_entries(entries)
        des=Array.new
        while entry=entries.pop
            tag_str=String.new
            while tag = entry[:tag].pop
                tag_str=tag_str + "["+tag+"]"
            end
            if entry[:summary]
                entry[:summary]=tag_str+entry[:summary]
            else
                entry[:summary]=tag_str
            end
                des.push entry
        end
        return des
    end
    module_function :marge_summary_entries
   
    #######################################
    # tagをsummaryにくっつける
    # 編集後のエントリを返す
    #######################################
    def marge_summary_entry(entry)
         des = entry.dup
         summary =  String.new
         while tag = entry[:tag].pop
             summary += "[#{tag}]"
         end
         des[:summary] = summary + entry[:summary].to_s
         return des
    end
    module_function :marge_summary_entry

    #######################################
    #与えられたentryの配列のタグをsrcから、desに編集する
    #######################################
    #def edit_entries(entries,src,des)
    def replace_tag(entries,src,des)
        des_entries = Array.new
        while entry = entries.pop
            if entry[:tag].include?(src)
                entry[:tag]=self.edit_tag_array(entry[:tag],src,des)
                des_entries.push(entry)
            end
        end
        return des_entries
    end
    module_function :replace_tag

    #######################################
    #タグ配列から、srcを探して、desに置き換える
    #置換後の配列を返す
    #######################################
    def edit_tag_array(tag_array,src,des)
        des_array=Array.new
        while tag=tag_array.pop
            if tag==src then
                tag=des.to_s  # exchenge!!
            end
            des_array.push(tag)
        end
        return des_array
    end
    #module_function :edit_tag_array
end
