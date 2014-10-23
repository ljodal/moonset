module Moonset
  class JobManager
    def initialize(opts = {})
      if opts[:use_workers]
        require 'rinda/tuplespace'

        @use_workers = true

        @ts = Rinda::TupleSpace.new

        DRb.start_service(nil, @ts)

        @url = DRb.uri
      else
        @jobs = []
      end
    end

    def connect
      if @use_workers
        require 'rinda/rinda'
        DRb.start_service
        @ts = Rinda::TupleSpaceProxy.new(DRbObject.new_with_uri(@url))
      end
    end

    def disconnect
      if @use_workers
        DRb.stop_service
      end
    end

    def add_file(input, output)
      if @use_workers
        @ts.write([:file, input, output])
      else
        @jobs << [input, output]
      end
    end

    def get_file
      if @use_workers
        type, input, output = @ts.take([:file, String, String])
        [input, output]
      else
        @jobs.shift
      end
    end

    def empty?
      if @use_workers
        @ts.read_all([:file, String, String]).empty?
      else
        @jobs.empty?
      end
    end
  end
end
