module Moonset
  class Worker
    def initialize(opts = {})
      if opts[:use_workers]
        require 'rinda/tuplespace'

        @use_workers = true

        @ts = Rinda::TupleSpace.new
      else
        @jobs = []
      end
    end
    def add_job(job)
      if @use_workers
        @ts.take([nil, String, String])
      else
        jobs.shift
      end
    end

    def get_job(job)
      if @use_workers
        @ts.write job
      else
        jobs << job
      end
    end
  end
end
