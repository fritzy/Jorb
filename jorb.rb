require 'rubygems'
require 'blather'
require 'jorb/pubsubjob'
require 'blather/client'

#after authenticating, binding to a jid, and sending presence
when_ready {
	
	#the first arguement is the jobs class instance
	def standardize(jobs)
		puts 'Standardizing address'
		#publish the initial address to the standardize node and store in standard_address
		jobs.publish 'standardize', jobs[:address], :standard_address
	end

	def geocode(jobs, type)
		if type == :address
			puts "Geocoding address"
			jobs.publish 'geocode', jobs[:standard_address], :geocode_address
		else
			puts "Geocoding block"
			jobs.publish 'geocode', jobs[:blockize_address], :geocode_block
		end
	end

	def blockize(jobs)
		puts "Blockize!"
		jobs.publish 'blockize', jobs[:standard_address], :blockize_address
	end

	def storedb(jobs)
		puts "Store!"
		out = "#{[jobs[:address], jobs[:standard_address].content, jobs[:blockize_address].content, jobs[:geocode_address].content, jobs[:geocode_block].content]}"
		jobs.publish 'storedb', jobs[:geocode_address], :store_db
	end

	def finish(jobs)
		puts "Finished!"
		#when a job is finished, the payload is stored, so it's a Nokogiri XML Object
		#XML.content gets the text node
		puts "Original Address: #{jobs[:address]}\nStandardized Address: #{jobs[:standard_address].content}\nBlockized Address: #{jobs[:blockize_address].content}\nAddress Geocoded: #{jobs[:geocode_address].content}\nBlock Geocoded: #{jobs[:geocode_block].content}"
	end
	
	#set up pubsub with domain of service
	pubsub = PubSub.new client, 'pubsub.debian'

	#Start a job sequence
	#Job sequences are necessary for workflow to store state for a single-threaded, asynchronous client.
	jobseq = Blather::JobSequence.new pubsub, client
	#set up steps with .next and a pointer
	# .wait indicates that all previous jobs should have results before continuing
	jobseq.next(method(:standardize)).wait
	# .next also takes an optional list of arguements for your pointer
	#notice that .next, wait, and done all return self
	jobseq.next(method(:geocode), [:address]).next(method(:blockize)).wait
	jobseq.next(method(:geocode), [:block]).wait
	jobseq.next(method(:storedb)).wait
	#done resets the jobseq index so that it can be used again
	jobseq.next(method(:finish)).done
	#setting our initial data
	jobseq[:address] = '2131 S. Vancouver'

	#this is when things start happening
	jobseq.run()
}
