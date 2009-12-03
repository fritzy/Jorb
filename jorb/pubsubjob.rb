#<iq to from type='set' id='claim1' >
#	<pubsubjob xmlns='http://... ' node='' item='' state='claim' />
#</iq>

#<iq type='error' id='claim1' />
#<iq type='result' id='claim1' />

module Blather

	module DSL
		class Jorb
			def initialize(client, host)
				@host = host
				@client = client
			end

			def client
				@client
			end

			# All job actions (other than publishing) make item state change
			# requests
			def set_job_state(channel, jobid, state, payload = nil)
				c = Stanza::PubSubJob.new(type=:set, host=@host)
				c.node = channel
				c.state = state
				c.item = jobid
				if payload
					#c.pubsubjob << payload
					c.payload = payload
				end
				c
			end 

			
			# Attempt to claim a job
			def claim(channel, jobid, &callback)
				request set_job_state(channel, jobid, :claimed), nil, callback
			end
			
			# Notify processing of job
			def process(channel, jobid, &callback)
				request set_job_state(channel, jobid, :processing), nil, callback
			end
			
			# Cancel a job
			def cancel(channel, jobid, reason=nil, &callback)
				request set_job_state(channel, jobid, :cancelled, reason), nil, callback
			end
			
			# Notify job finished and optionally send result
			def finish(channel, jobid, payload, &callback)
				request set_job_state(channel, jobid, :finished, payload), nil, callback
			end

			private
			def request(node, method = nil, callback = nil, &block)
				unless block_given?
					block = lambda do |node|
						callback.call(method ? node.__send__(method) : node)
					end
				end

				client.write_with_handler(node, &block)
			end

		end #Jorb
	end # DSL

class Stanza
	class PubSubJob < Iq
		register(:job_node, :pubsubjob, 'http://andyet.net/protocol/pubsubjob')

		# @private
		def self.import(node)
			klass = nil
			if pubsubjob = node.document.find_first('//ns:pubsubjob', :ns => self.registered_ns)
				pubsubjob.children.detect do |e|
					ns = e.namespace ? e.namespace.href : nil
					klass = class_from_registration(e.element_name, ns)
				end
			end
			(klass || self).new(node[:type]).inherit(node)
		end
    
# Overwrites the parent constructor to ensure a pubsub node is present.
# Also allows the addition of a host attribute
#
# @param [<Blather::Stanza::Iq::VALID_TYPES>] type the IQ type
# @param [String, nil] host the host the node should be sent to
		def self.new(type = :set, host = nil)
			new_node = super type
			new_node.to = host
			new_node.pubsubjob
			new_node
		end

# Overrides the parent to ensure the current pubsub node is destroyed before
# inheritting the new content
#
		# @private
		def inherit(node)
			remove_children :pubsub
			super
		end

		def node=(node)
			pubsubjob[:node] = node
		end

		def node
			pubsubjob[:node]
		end

		def state=(state)
			pubsubjob[:state] = state
		end

		def state
			pubsubjob[:state]
		end

		def item=(item)
			pubsubjob[:item] = item
		end 

		def item
			pubsubjob[:item]
		end

		def payload
			pubsubjob.child
		end

		def payload=(content)
			pubsubjob << content
		end

    
	# Get or create the pubsub node on the stanza
    #
    # @return [Blather::XMPPNode]
		def pubsubjob
			p = find_first('ns:pubsubjob', :ns => self.class.registered_ns) 
			unless p
				p = XMPPNode.new('pubsubjob', self.document)
				self << p
				p.namespace = self.class.registered_ns
			end
			p
		end

	end

end #Stanza
end #Blather

module Blather

class JobSequence
	def initialize pubsub, client
		@step = 0
		@steps = []
		@ran_steps = []
		@results = {}
		@result_map = {}
		@pending = []
		@waiting = false
		@pubsub = pubsub
		@client = client

		pubsubjob_event :state => 'finished' do |p|
			if @result_map.has_key? p.jobid
				@results[@result_map[p.jobid]] = p.payload
				@result_map.delete p.jobid
			end
			@pending.delete p.jobid
			if @pending.length == 0 && @waiting
				@waiting = false
				runnext
			end
		end
	end

	def steps=(steps)
		@steps = steps
	end

	def []=(key, value)
		@results[key] = value
	end

	def [](key)
		@results[key]
	end

	def run
		runnext
	end

	def next(pointer, args=[])
		@steps << [pointer, args]
		self
	end

	def wait
		@steps << :wait
		self
	end

	def done
		@steps << :done
		self
	end

	def runnext
		while !@waiting && @step < @steps.length
			if @steps[@step] == :wait
				@waiting = true
			elsif @steps[@step] == :done
				@step = 0
				@waiting = false
				break
			else
				pointer, args = @steps[@step]
				pointer.call self, *args
				#@steps[@step].call self
			end
			@step += 1
		end
	end

	def publish(node, payload, result_name)
		pubsub.publish node, payload do |iq|
			iq.items.each do |item|
				@pending << item[:id]
				@result_map[item[:id]] = result_name
			end
		end
	end
end
	class Stanza
	
		class PubSubJob
		
		class JobEvent < Message
			register :pubsubjob_event, :pubsubjob, 'http://andyet.net/protocol/pubsubjob#event'

		def self.new(type = nil)
		  node = super
		  node.event_node
		  node
		end

		def inherit(node)
		  event_node.remove
		  super
		end

		def node
		  event_node[:node]
		end

		def jobid
			event_node[:item]
		end

		def state
			event_node[:state]
		end

		def claimed?
			event_node[:state] == 'claimed'
		end
		
		def processing?
			event_node[:state] == 'processing'
		end
		
		def finished?
			event_node[:state] == 'finished'
		end

		def cancelled?
			event_node[:state] == 'cancelled'
		end

		def payload
			event_node.child
		end

		def event_node
		  node = find_first('//ns:pubsubjob', :ns => self.class.registered_ns)
		  node = find_first('//pubsubjob', self.class.registered_ns) unless node
		  unless node
			(self << (node = XMPPNode.new('pubsubjob', self.document)))
			node.namespace = self.class.registered_ns
		  end
		  node
		end

		end

		end
	end
end
