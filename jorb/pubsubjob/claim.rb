Module Blather
class Stanza
class Jorb

	class Claim < Jorb
	
		register :jorb_claim, :claim self.registered_ns

		def self.new(type=:get, host=nil, node=nil, item=nil)
			new_node = super(type, host)
			new_node.job = node, item
			new_node
		end

		def job
			[pubsubjob[:node], pubsubjob[:item]]
		end

		def job=(node, item_id)
			unless item = pubsubjob.attr[:item]
				self.pubsubjob.attr[:item] = item_id
			end
			unless node = pubsubjob.attr[:node]
				self.pubsubjob.attr[:node] = node
			end
		end

