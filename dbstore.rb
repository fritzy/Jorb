#require 'rubygems'
#require 'blather/client'


#so the ordering here is important, and Jeff is working on fixing that
#require 'blather/blather'
#require 'jorb/pubsubjob'
#require 'blather/blather/client'

require 'blather'
require 'jorb/pubsubjob'
require 'blather/client'

# should be able to do pubsub.host =, but Jeff has a bug with knowing the
# client.jid if you use CLI options instead of 'setup'
pubsub = PubSub.new client, 'pubsub.debian'
jorb = Blather::DSL::Jorb.new client, 'pubsub.debian'

pubsub_event  do |job|
	puts 'Got Geocode event'
	puts job.items?
	job.items_node.children.each do |item|
		puts item[:id]
		jorb.claim 'geocode', item[:id] do |result|
			puts result.type
		end
	end
end

pubsubjob_event do |p|
	puts 'someone claimed a job!'
	puts p
end

when_ready {
	pubsub.publish 'geocode', 'Happy fun land!'
#	jorb = Blather::DSL::Jorb.new client, 'pubsub.debian'
#	jorb.claim('geocode', 'job32') do |result|
#		if result.type == :error
#			puts "There was an error!"
#		else
#			puts "Looks like a result to me"
#		end
#	end
}

