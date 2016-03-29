1.3.3 (March 29, 2016)
======================
- Upgrade to support Logstash v2.2.2
- Convert the old plugin code into a proper Ruby Gem.
- Rename the plugin from "lucidworks_solr_lsv133" to simply "lucidworks_solr"

1.0.0 (March 27, 2014)
======================
  # General
  -  With the exception of the @timestamp and @version fields [see below] the application will no longer try and 
  	explicitly create fields dynamically.  Collections must either use a managed_schema or an appropriately configured 
  	unmanaged schema that predefines all expected fields. 
    
    With managed schema the type of new fields will be automatically determined by Solr.    
    With unmanaged schema the user explicitly defines the type of all incoming fields ('*' can be defined in an 
    unmanaged schema to be the default type of all incoming unknown fields.) 
    
    For the mandatory fields @timestamp and @version the program will check for their existence at startup and if these fields 
    do not exist then it will attempt to create them with the following types: 

	Timestamp
		type: tdate
		name: appends prefix value from config file or logstash_ by default to 'timestamp'. ex: logstash_timestamp
		stored: true
		indexed: true
	
	Version
		type: long
		name: appends prefix value from config file or logstash_ by default to 'version'.  ex: logstash_version
		stored: true
		indexed: true

	An exception gets thrown if these fields do not exist and field creation fails.  
	
  - Uses Logstash version 1.3.3
  - Added LucidWorks Logstash 1.3.3 output file lucidworks_solr_lsv133.rb
  - Added new configuration settings that allow user better control of performance characteristics.

    output {
		  lucidworks_solr_lsv133 {
		    ...
			force_commit => ... # boolean (optional), default: false
		    flush_size => ... # number (optional), default: 100
		    idle_flush_time => ... # number (optional), default: 1
		  }
	}
    
	force_commit
		Value type is boolean
		Default is false
		
	If true then a commit request will be sent to Solr for each batch of documents.  If false then 
	the documents will be commited per the Solr instance's configured commit policy.
	
	The output uses Logstash's stud buffer to handle buffering events for batched document uploads.  The next two 
	field values get passed to the buffer manager.
	
	flush_size
	  Value type is number
	  Default is 100
	  
	Number of events to queue up before writing to Solr.  The implementation uses Logstash's stud event buffering.
	
	idle_flush_time
	  Value type is number
	  Default is 1
	  
	Amount of time in seconds since the last flush before a flush is done even if the number of buffered events is smaller than flush_size
