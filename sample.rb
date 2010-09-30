#!/usr/bin/env ruby 
$KCODE="UTF8"
require 'hatebu'

banner = <<DATA
 select what you want
 1 print recent entries
 2 print recent entries search by tag
 3 create new entry
DATA

print 'input Hatena id:'
@id = gets.chomp
print 'input password:'
@password = gets.chomp

def print_recent_entries
    hatebu = HatebuAPI.new(@id,@password)
    entries = hatebu.get_feed
    entries.each{|entry|
        print "id: #{entry[:id]} summary: #{entry[:summary]} tag:"
        entry[:tag].each{|tag|
            print "[#{tag}]"
        }
        print "\n"
    }
end

def print_entries_by_tag
    hatebu = HatebuAPI.new(@id,@password)
    print "input tag:"
    tag = gets.chomp
    entries = hatebu.get_feed_by_tag(tag,1)
    entries.each{|entry|
        print "\n---\n"
        print "id: #{entry[:id]} summary: #{entry[:summary]} tag:"
        entry[:tag].each{|tag|
            print "[#{tag}]"
        }
        print "\n"
    }
end

def create_entry
    print "input url"
    url = gets.chomp
    print "input summary"
    summary=gets.chomp

    hatebu = HatebuAPI.new(@id,@password)
    id = hatebu.create_entry({:url => url ,
                              :summary=> summary })
    print "created entry id: #{id}"
end

loop{
    print banner
    case gets.chomp.to_i
    when 1 then
        print_recent_entries
    when 2 then
        print_entries_by_tag
    when 3 then
        create_entry
    end
}

