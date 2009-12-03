require 'rubygems'
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


when_ready {
	p = Blather::Stanza::Presence.new
	p.to = 'pubsub.debian'
	client.write p

	pubsub_event :node => 'geocode' do |job|
		puts "Got event #{job.node}"
		job.items.each do |item|
			puts "#{job.node} job: #{item[:id]}"
			jorb.claim job.node, item[:id] do |claimr|
				if claimr.result?
					puts "Claimed Job"
					jorb.process job.node, item[:id] do |processr|
						if processr.result?
							puts "Processing Job"
							jobxml = Blather::XMPPNode.new('job')
							jobxml.content = '73.35352523, 43.425125124'
							jorb.finish job.node, item[:id], jobxml do |finishr|
								puts "Finished Job"
							end
						end
					end
				end
			end
		end
	end
}
