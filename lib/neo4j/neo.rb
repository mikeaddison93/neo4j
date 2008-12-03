module Neo4j


  # Starts neo.
  # Before using neo it has to be started and the location of the Neo database on the filesystem must
  # have been configured, Neo4j::Config[:storage_path].
  #
  # ==== Examples
  # Neo4j::Config[:storage_path] = '/var/neo4j-db'
  # Neo4j.start
  #
  # ==== Returns
  # The neo instance
  #
  # @raise [StandardError] if Neo already has been started
  # :api: public
  def self.start
    raise StandardError.new("Already started neo") if @instance
    @instance = Neo.new 
    @instance.start
  end

  #
  # Return the started neo instance or nil if not started
  # 
  # ==== Returns
  # The neo instance
  # 
  # :api: public
  def self.instance
    @instance
  end

  # Stops the current instance unless it is not started.
  # This must be done in order to avoid corrupt neo database.
  # 
  # :api: public
  def self.stop
    @instance.stop unless @instance.nil?
    @instance = nil
  end

  # 
  # Returns true if neo4j is running
  #
  def self.running?
    ! @instance.nil?
  end
  
  
  #
  # Allows run and stop the Neo4j service
  # Contains global ćonstants such as location of the neo storage and index files
  # on the filesystem.
  # 
  # A wrapper class around org.neo4j.api.core.EmbeddedNeo
  # 
  class Neo

    #
    # ref_node : the reference, ReferenceNode, node, wraps a org.neo4j.api.core.NeoService#getReferenceNode
    #
    attr_reader :ref_node

    def start
      @neo = org.neo4j.api.core.EmbeddedNeo.new(Neo4j::Config[:storage_path])
      Transaction.run { @ref_node = ReferenceNode.new(@neo.getReferenceNode()) }
      $NEO_LOGGER.info{ "Started neo. Database storage located at '#{@db_storage}'"}
    end
    
    #
    # Create an internal neo node (returns a java object)
    # Don't use this method - only for internal use.
    #
    def create_node
      @neo.createNode
    end

    #
    # Returns an internal neo transaction object.
    # Don't use this method - only for internal use.
    #
    def begin_transaction
      @neo.begin_tx
    end

    
    #
    # Returns a NodeMixin object that has the given id or nil if it does not exist.
    # 
    def find_node(id) 
      begin
        Transaction.run do
          neo_node = @neo.getNodeById(id)
          load_node(neo_node)
        end
      rescue org.neo4j.api.core.NotFoundException 
        nil
      end
    end
  


    #
    # Loads a Neo node
    # Expects the neo property 'classname' to exist.
    # That property is used to load the ruby instance
    #
    def load_node(neo_node)
      return nil unless neo_node.has_property('classname')
      _load neo_node.get_property('classname'), neo_node
    end


    #
    # Loads a Neo relationship
    # If the neo property 'classname' to exist it will use that to create an instance of that class.
    # Otherwise it will create an instance of Neo4j::Relations::DynamicRelation that represent 'rel'
    #
    def load_relationship(rel)
      classname = rel.get_property('classname') if rel.has_property('classname')
      classname = Neo4j::Relations::DynamicRelation.to_s if classname.nil?
      _load classname, rel
    end

    def _load(classname, node_or_relationship)
      clazz = classname.split("::").inject(Kernel) do |container, name|
        container.const_get(name.to_s)
      end
      clazz.new(node_or_relationship)
    end
    
    #
    # Stop neo
    # Must be done before the program stops
    #
    def stop
      $NEO_LOGGER.info {"stop neo #{@neo}"}
      @neo.shutdown  
      @neo = nil
    end


    
    def tx_manager
      @neo.getConfig().getTxModule().getTxManager()
    end
    
    
  end
end
