#!/usr/bin/env ruby

require 'test/unit'
require 'hatebu'

class Hatebu_test < Test::Unit::TestCase

    #
    #
    #
    def setup
       id      ="zonoise"
       password="68391566"
       @hatebu = HatebuAPI.new(id,password)
    end

 
    #
    # Testing get_feed method
    #
    def test_get_feed
        assert_nothing_raised("failed"){
            entries = @hatebu.get_feed 

            # array of entry has correct member ?

            assert_equal(entries.instance_of?(Array),true)
            entry= entries.pop
            assert_equal(entry.instance_of?(Hash) ,true)
            assert_equal(entry.has_key?(:id)     ,true)
            assert_equal(entry.has_key?(:title)  ,true)
            assert_equal(entry.has_key?(:summary) ,true)
            assert_equal(entry.has_key?(:tag)    ,true)
            assert_equal(entry[:tag].instance_of?(Array) ,true)
            puts entry
        }
    end 
 
    #
    # Testing get_feed_by_tag method
    #
    def test_get_feed_tag
        assert_nothing_raised("failed"){
            entries = @hatebu.get_feed_by_tag("あとで読む",1)
            entries.each{|e|
                puts e[:id]
                puts e[:title]
                puts e[:summary]
                puts e[:tag]
            }
	}
    end

    #
    # edit tag array
    #
    def test_edit_tag_array
        src=["aaa","bbb","ccc"]
        des = HatebuEntries::edit_tag_array(src,"ccc","ddd")
        assert_equal(des.include?("ccc"),false ,"error at#{__LINE__}")
        assert_equal(des.include?("ddd"),true,"error at#{__LINE__}")
    end

    #
    # 配列に含まれるエントリのタグをbeforeからafterへ編集する
    # 
    def test_replace_tag
        entries = @hatebu.get_feed_by_tag("あとで読む",1)
        edited = HatebuEntries::replace_tag(entries,"あとで読む","ATO")
    end
   
    #
    # ダウンロードしたデータをアップロードに適した形に整形
    # 別の言い方をすると[:tag]を [:summary] に結合する
    def test_update_entries
        src = @hatebu.get_feed_by_tag("tmp",1)
        des = HatebuEntries.update_entries(src)
      #  des.each{|e|
      #      puts e[:id]
      #      puts e[:summary] 
      #  }
    end

    #
    # 一つのエントリのサマリーを更新する
    # んーテストの方法に悩み中、
    # def test_put_entry
    #   #http://b.hatena.ne.jp/zonoise/20100928#bookmark-25266084
    #   @hatebu.put_entry(25266084,"こんにちはこんにちは")
    #end


    # 新規ブックマーク成功
    def test_post
        assert_nothing_raised("test_post"){
            entry={:url => 'http://www.jma.go.jp/jma/index.html',
               :summary => 'tenki'}
    
            id = @hatebu.create_entry(entry)
            p id
        }
    end
    # 新規ブックマーク失敗
    def test_post_fail
        #invalid URL 
        assert_raise(RuntimeError,"test_post_fail"){ 
            entry={:url => 'httppp',
               :summary => 'tenki',
               :tag => ['webservice','tmp']}
               res = @hatebu.create_entry(entry)
        }
    end

    # ブックマーク削除のテスト
    def test_delete_entry
   #     entry={:url => 'http://www.jma.go.jp/jma/index.html',
   #            :summary => 'tenki'}
   #     id = @hatebu.create_entry(entry)
#
#        res = @hatebu.delete_entry(id)
        res = @hatebu.delete_entry("551389")
        pp res     
    end
end

class Hatebu_Entries < Test::Unit::TestCase
    def test_marge_summary_entry
        entry={:summary => "summary",
               :tag     => ["tagA","tagB"]}
        des=HatebuEntries::marge_summary_entry(entry)
        #タグから、サマリーにマージしているか確認
        assert_equal(des[:summary].include?("tagA"),true)
        assert_equal(des[:summary].include?("tagB"),true)
    end
end
