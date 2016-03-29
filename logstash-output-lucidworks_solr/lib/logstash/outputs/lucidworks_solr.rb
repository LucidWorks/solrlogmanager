# encoding: utf-8
require "logstash/namespace"
require "logstash/outputs/base"
require "net/http"
require "stud/buffer"
require "time"
#require "active_support"
#require "pry"

require "lucidworks.jar"


# LucidWorks output that pushes Logstash collected logs to Solr. 
#
# You can learn more about LucidWorks and Solr at <http://www.lucidworks.com/>
class LogStash::Outputs::LucidWorks < LogStash::Outputs::Base
	include Stud::Buffer

  config_name "lucidworks_solr"
  
  # The config values are set here to default settings.  They are overridden by the 
  # logstash conf file settings.
  
  # Solr host 
  config :collection_host, :validate => :string, :default => "localhost"

  # Port (default solr port = 8983)
  config :collection_port, :validate => :number, :default => 8983
  
  # Collection name 
  config :collection_name, :validate => :string, :default => "collection1"

  # Prefix will replace the @ in logstash fieldnames @timestash and @version.
  config :field_prefix, :validate => :string, :default => "logstash_"
 
  # Solr solrconfig.xml can be configured to automatically commit documents after a 
  # specified amount of time or after receipt of a maximum number of documents.  For convenience 
  # allow the logger to override this setting for use in cases where the site either isn't 
  # setting the configuration or where it is desired that logs be available for review sooner than the
  # xml configuration allows.
  #
  # If false then rely on the solrconfig setting.  If true then force an immediate commit for each received document. 
  # Note that it takes this module ~twice as long to process each document when this setting is true.
  config :force_commit, :validate => :boolean, :default => false
 
  # Number of events to queue up before writing to Solr
  config :flush_size, :validate => :number, :default => 100

  # Amount of time since the last flush before a flush is done even if
  # the number of buffered events is smaller than flush_size
  config :idle_flush_time, :validate => :number, :default => 1

  @lucidworks
 
  public
  def register

    @lucidworks = Java::LWSolrLogCollectionManager.new()

    # All fields are expected to either already be defined in the collection schema.  Or, expect that a managed-schema is being used.
    # As a convenience we here try to insure that two mandatory SiLK fields exist and if they do not we will try and 
    # have Solr create them.
   
    @lucidworks.init(@collection_host, @collection_port, @collection_name, @force_commit)
 
  	@lucidworks.createSchemaField(@field_prefix + "timestamp", "\"type\":\"tdate\",\"name\":\"" + @field_prefix + "timestamp" + "\",\"stored\":true,\"indexed\":true")
  	@lucidworks.createSchemaField(@field_prefix + "version", "\"type\":\"long\",\"name\":\"" + @field_prefix + "version" + "\",\"stored\":true,\"indexed\":true")
   
    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )
  end # def register

  public
  def receive(event)
    return unless output?(event)

    # NOTES: 
    #   1) Field names must conform to Solr field naming conventions.
    #   2) The tags field is expected to be an collection of name/value pairs.  They are here joined by commas and are
    #      later stored in the collection as multiple select field items.
    #   3) If in the future there are other fields that are collection types then a new case must be added here to either treat them as
    #      tags or to break them out as individual name/value field items as is expected in the final 'else' below.     
    #   4) Each item stored in a Solr index must have a unique ID.  You can manage the ID's by adding your own ID to 
    #      solrfields collection.  If that field is not added here then addSolrDocument call will automatically generate a GUIID 
    #      that will be the record ID.  (Note that if you pass an existing ID then the associated Solr record's data will be 
    #      overwritten.
    solrfields = Hash.new
    lucidfields = event.to_hash
    lucidfields.each { |key,value|
      case key
      when "tags"
        solrfields["#{key}"]= value.join(",")
      when "@timestamp"   
        # @timestamp looks like - 2014-03-25 21:48:35 -0700 
        # Solr's format is 2014-03-25T23:48:35.591 and @ is invalid in Solr field names so fix here.
        solrfields[@field_prefix + "timestamp"] = DateTime.iso8601(Time.parse("#{value}").iso8601).strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      when "@version"
        solrfields[@field_prefix + "version"] = "#{value}"
      else
        solrfields["#{key}"] = "#{value}"
      end
    }
    
    begin
      s = @lucidworks.createSolrDocument(java.util.HashMap.new(solrfields))
      buffer_receive(s)
    rescue Exception => e
      puts "Exception occured constructing new solr document - " + e.message  
    end
    #binding.pry
  end # def receive
  
  def flush(events, teardown=false)
  	begin 
   		documents = "" 
    	events.each do |event|
    		documents += event
    	end

   		@lucidworks.flushDocs(documents)
 
  	rescue Exception => e
    	@logger.warn("An error occurred while flushing events: #{e.message}")
		end
  end #def flush
end 
